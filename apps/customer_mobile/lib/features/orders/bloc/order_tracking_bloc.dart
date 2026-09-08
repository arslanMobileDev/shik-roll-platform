import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cart/data/orders_repository.dart';
import '../data/order_tracking_repository.dart';
import '../domain/order_timeline.dart';

/// Команды [OrderTrackingBloc] (ADR-1615).
sealed class OrderTrackingEvent extends Equatable {
  const OrderTrackingEvent();

  @override
  List<Object?> get props => [];
}

/// Открыть трекинг заказа (экран появился / повтор после ошибки загрузки).
final class OrderTrackingStarted extends OrderTrackingEvent {
  const OrderTrackingStarted(this.orderId);

  final String orderId;

  @override
  List<Object?> get props => [orderId];
}

/// Принудительный snapshot refresh (foreground/resume по ADR-1615).
final class OrderTrackingRefreshed extends OrderTrackingEvent {
  const OrderTrackingRefreshed();
}

/// Пришло событие из SSE-стрима.
final class _OrderTimelineReceived extends OrderTrackingEvent {
  const _OrderTimelineReceived(this.update);

  final OrderTrackingUpdate update;

  @override
  List<Object?> get props => [update];
}

/// SSE-стрим оборвался (ошибка транспорта или закрытие сервером).
final class _OrderTrackingDisconnected extends OrderTrackingEvent {
  const _OrderTrackingDisconnected();
}

/// Таймер backoff: пора переподключать SSE.
final class _OrderTrackingRetried extends OrderTrackingEvent {
  const _OrderTrackingRetried();
}

/// Тик fallback-поллинга, пока SSE недоступен.
final class _OrderTrackingPollTicked extends OrderTrackingEvent {
  const _OrderTrackingPollTicked();
}

/// Состояние трекера заказа (контракт ADR-1615: status, progressPercent,
/// orderVersion, isConnected, estimatedDeliveryAt).
final class OrderTrackingState extends Equatable {
  const OrderTrackingState({
    this.timeline,
    this.isConnected = false,
    this.errorMessage,
  });

  /// Последняя применённая timeline-проекция; `null` — snapshot ещё грузится.
  final OrderTimeline? timeline;

  /// `true`, пока жив SSE-стрим. При `false` работает fallback-поллинг.
  final bool isConnected;

  /// Ошибка первичной загрузки (snapshot так и не получен).
  final String? errorMessage;

  bool get isLoading => timeline == null && errorMessage == null;

  bool get loadFailed => timeline == null && errorMessage != null;

  OrderTimelineStatus? get status => timeline?.status;

  bool get isCancelled => timeline?.isCancelled ?? false;

  int get progressPercent => timeline?.progressPercent ?? 0;

  int get orderVersion => timeline?.orderVersion ?? 0;

  DateTime? get estimatedDeliveryAt => timeline?.estimatedDeliveryAt;

  DateTime? get updatedAt => timeline?.updatedAt;

  OrderTrackingState copyWith({
    OrderTimeline? timeline,
    bool? isConnected,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OrderTrackingState(
      timeline: timeline ?? this.timeline,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [timeline, isConnected, errorMessage];
}

/// Трекинг одного заказа: snapshot → SSE-стрим; при обрыве — fallback-
/// поллинг и переподключение с exponential backoff + jitter (ADR-1615).
class OrderTrackingBloc extends Bloc<OrderTrackingEvent, OrderTrackingState> {
  OrderTrackingBloc({
    required this._repository,
    this._pollingInterval = const Duration(seconds: 15),
    this._retryBaseDelay = const Duration(seconds: 1),
    this._maxRetryDelay = const Duration(seconds: 30),
    this._maxRetryJitter = const Duration(milliseconds: 500),
    Random? random,
  }) : _random = random ?? Random(),
       super(const OrderTrackingState()) {

    on<OrderTrackingStarted>(_onStarted);
    on<OrderTrackingRefreshed>(_onRefreshed);
    on<_OrderTimelineReceived>(_onTimelineReceived);
    on<_OrderTrackingDisconnected>(_onDisconnected);
    on<_OrderTrackingRetried>(_onRetried);
    on<_OrderTrackingPollTicked>(_onPollTicked);
  }

  final OrderTrackingRepository _repository;
  final Duration _pollingInterval;
  final Duration _retryBaseDelay;
  final Duration _maxRetryDelay;
  final Duration _maxRetryJitter;
  final Random _random;

  String? _orderId;
  bool _started = false;
  int _retryAttempt = 0;
  StreamSubscription<OrderTrackingUpdate>? _streamSubscription;
  Timer? _retryTimer;
  Timer? _pollTimer;

  Future<void> _onStarted(
    OrderTrackingStarted event,
    Emitter<OrderTrackingState> emit,
  ) async {
    // Повторный Started для того же заказа игнорируем, если трекинг жив;
    // после ошибки загрузки — это retry, проходим заново.
    if (_started && _orderId == event.orderId && !state.loadFailed) return;
    _started = true;
    _orderId = event.orderId;
    _retryAttempt = 0;
    _stopPolling();
    _retryTimer?.cancel();
    unawaited(_streamSubscription?.cancel());
    emit(const OrderTrackingState());

    try {
      // Snapshot первым: realtime — только ускоритель UI (ADR-1615).
      final snapshot = await _repository.getOrderSnapshot(event.orderId);
      emit(
        OrderTrackingState(timeline: snapshot.timeline, isConnected: false),
      );
    } on OrdersException catch (e) {
      emit(OrderTrackingState(errorMessage: e.message));
      return;
    }
    _openStream();
  }

  Future<void> _onRefreshed(
    OrderTrackingRefreshed event,
    Emitter<OrderTrackingState> emit,
  ) async {
    final orderId = _orderId;
    if (orderId == null || state.loadFailed) return;
    try {
      _applySnapshot(await _repository.getOrderSnapshot(orderId), emit);
    } on OrdersException {
      // Ручной refresh молча оставляет прежнее состояние.
    }
  }

  void _onTimelineReceived(
    _OrderTimelineReceived event,
    Emitter<OrderTrackingState> emit,
  ) {
    _retryAttempt = 0;
    _stopPolling();
    _applySnapshot(event.update, emit, markConnected: true);
  }

  void _onDisconnected(
    _OrderTrackingDisconnected event,
    Emitter<OrderTrackingState> emit,
  ) {
    // До первого snapshot трекинг не запущен — экран показывает ошибку.
    if (state.loadFailed) return;
    emit(state.copyWith(isConnected: false));
    _startPolling();
    _scheduleRetry();
  }

  void _onRetried(
    _OrderTrackingRetried event,
    Emitter<OrderTrackingState> emit,
  ) {
    _openStream();
  }

  Future<void> _onPollTicked(
    _OrderTrackingPollTicked event,
    Emitter<OrderTrackingState> emit,
  ) async {
    final orderId = _orderId;
    if (orderId == null) return;
    try {
      // Поллинг двигает проекцию, но не помечает стрим подключённым.
      _applySnapshot(await _repository.getOrderSnapshot(orderId), emit);
    } on OrdersException {
      // Остаёмся офлайн до следующего тика/переподключения.
    }
  }

  /// Применяет обновление, отсекая устаревшие версии (ADR-1615: события
  /// с `order_version <=` текущей игнорируются). Snapshot из поллинга без
  /// версии применяется только при изменении проекции и не сбрасывает
  /// version-floor — иначе устаревшее версионное событие могло бы
  /// откатить проекцию назад.
  void _applySnapshot(
    OrderTrackingUpdate update,
    Emitter<OrderTrackingState> emit, {
    bool markConnected = false,
  }) {
    final version = update.version;
    if (version != null && version <= state.orderVersion) return;
    final timeline = update.timelineWithVersionFloor(state.orderVersion);
    final connected = markConnected || state.isConnected;
    if (timeline == state.timeline && connected == state.isConnected) return;
    emit(
      state.copyWith(
        timeline: timeline,
        isConnected: connected,
        clearError: true,
      ),
    );
  }

  void _openStream() {
    final orderId = _orderId;
    if (orderId == null) return;
    unawaited(_streamSubscription?.cancel());
    _streamSubscription = _repository
        .openTrackingStream(orderId)
        .listen(
          (update) => add(_OrderTimelineReceived(update)),
          onError: (_) => add(const _OrderTrackingDisconnected()),
          onDone: () => add(const _OrderTrackingDisconnected()),
          cancelOnError: true,
        );
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(
      _pollingInterval,
      (_) => add(const _OrderTrackingPollTicked()),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    // 1s, 2s, 4s, … с потолком _maxRetryDelay и положительным jitter.
    final shift = _retryAttempt.clamp(0, 5);
    _retryAttempt++;
    var delay = _retryBaseDelay * (1 << shift);
    if (delay > _maxRetryDelay) delay = _maxRetryDelay;
    final jitterMs = _maxRetryJitter.inMilliseconds;
    final jitter = jitterMs > 0
        ? Duration(milliseconds: _random.nextInt(jitterMs + 1))
        : Duration.zero;
    _retryTimer = Timer(delay + jitter, () {
      add(const _OrderTrackingRetried());
    });
  }

  @override
  Future<void> close() async {
    _retryTimer?.cancel();
    _stopPolling();
    await _streamSubscription?.cancel();
    return super.close();
  }
}
