import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/kds_order_models.dart';
import '../data/kds_orders_repository.dart';
import 'kds_orders_event.dart';
import 'kds_orders_state.dart';

/// Kitchen board: active orders for a branch with periodic polling and real-time SSE stream.
class KdsOrdersBloc extends Bloc<KdsOrdersEvent, KdsOrdersState> {
  KdsOrdersBloc({
    required this.repository,
    this.pollInterval = const Duration(seconds: 10),
  }) : super(const KdsOrdersLoading()) {
    on<KdsOrdersStarted>(_onStarted);
    on<KdsOrdersRefreshed>(_onRefreshed);
    on<KdsOrdersPollTicked>(_onPollTicked);
    on<KdsOrdersStreamEventReceived>(_onStreamEventReceived);
    on<KdsOrderStatusChangeRequested>(_onStatusChangeRequested);
    on<KdsOrdersNewOrdersAcknowledged>(_onNewOrdersAcknowledged);
  }

  final KdsOrdersRepository repository;

  /// Polling cadence; `null` disables polling (widget tests).
  final Duration? pollInterval;

  Timer? _pollTimer;
  StreamSubscription<void>? _sseSubscription;
  String? _branchId;

  /// Ids the board has already shown.
  final Set<String> _seenOrderIds = {};

  Future<void> _onStarted(
    KdsOrdersStarted event,
    Emitter<KdsOrdersState> emit,
  ) async {
    _branchId = event.branchId;
    _startPolling();
    _startSseSubscription(event.branchId);
    await _load(emit, showLoading: true);
  }

  Future<void> _onRefreshed(
    KdsOrdersRefreshed event,
    Emitter<KdsOrdersState> emit,
  ) => _load(emit, showLoading: state.orders == null);

  Future<void> _onPollTicked(
    KdsOrdersPollTicked event,
    Emitter<KdsOrdersState> emit,
  ) => _load(emit, showLoading: false);

  Future<void> _onStatusChangeRequested(
    KdsOrderStatusChangeRequested event,
    Emitter<KdsOrdersState> emit,
  ) async {
    final current = state.orders;
    if (current == null) return;

    emit(
      KdsOrdersActionInProgress(
        orders: current,
        pendingOrderId: event.orderId,
        connectionStatus: state.connectionStatus,
      ),
    );
    try {
      await repository.updateOrderStatus(
        orderId: event.orderId,
        status: event.status,
        cookId: event.cookId,
        shiftId: event.shiftId,
      );
      await _load(emit, showLoading: false);
    } catch (e) {
      emit(
        KdsOrdersLoaded(
          orders: current,
          lastUpdatedAt: DateTime.now(),
          actionError: 'Не удалось обновить статус: $e',
          connectionStatus: state.connectionStatus,
        ),
      );
    }
  }

  void _onStreamEventReceived(
    KdsOrdersStreamEventReceived event,
    Emitter<KdsOrdersState> emit,
  ) {
    switch (event.streamEvent) {
      case KdsOrdersStreamEvent.connecting:
        _emitConnectionStatus(emit, KdsConnectionStatus.connecting);
      case KdsOrdersStreamEvent.connected:
        _emitConnectionStatus(emit, KdsConnectionStatus.online);
        // A full sync closes the gap that may have formed while SSE was down.
        add(const KdsOrdersPollTicked());
      case KdsOrdersStreamEvent.reconnecting:
        _emitConnectionStatus(emit, KdsConnectionStatus.reconnecting);
      case KdsOrdersStreamEvent.disconnected:
        _emitConnectionStatus(emit, KdsConnectionStatus.offline);
      case KdsOrdersStreamEvent.ordersChanged:
        add(const KdsOrdersPollTicked());
    }
  }

  void _emitConnectionStatus(
    Emitter<KdsOrdersState> emit,
    KdsConnectionStatus status,
  ) {
    if (state.connectionStatus == status) return;
    emit(
      switch (state) {
        KdsOrdersLoading() => KdsOrdersLoading(connectionStatus: status),
        final KdsOrdersLoaded loaded => loaded.copyWith(
          connectionStatus: status,
        ),
        KdsOrdersActionInProgress(:final orders, :final pendingOrderId) =>
          KdsOrdersActionInProgress(
            orders: orders,
            pendingOrderId: pendingOrderId,
            connectionStatus: status,
          ),
        KdsOrdersError(:final message) => KdsOrdersError(
          message,
          connectionStatus: status,
        ),
      },
    );
  }

  void _onNewOrdersAcknowledged(
    KdsOrdersNewOrdersAcknowledged event,
    Emitter<KdsOrdersState> emit,
  ) {
    final current = state;
    if (current is KdsOrdersLoaded && current.freshOrderIds.isNotEmpty) {
      emit(current.copyWith(freshOrderIds: const {}));
    }
  }

  Future<void> _load(
    Emitter<KdsOrdersState> emit, {
    required bool showLoading,
  }) async {
    final branchId = _branchId;
    if (branchId == null) return;
    if (showLoading) {
      emit(KdsOrdersLoading(connectionStatus: state.connectionStatus));
    }

    try {
      final fetched = await repository.fetchOrders(branchId: branchId);
      final orders = _sortedActive(fetched);

      final fresh = <String>{};
      for (final order in orders) {
        if (!_seenOrderIds.contains(order.id)) fresh.add(order.id);
      }
      _seenOrderIds
        ..clear()
        ..addAll(orders.map((o) => o.id));

      emit(
        KdsOrdersLoaded(
          orders: orders,
          lastUpdatedAt: DateTime.now(),
          freshOrderIds: state.orders == null ? const {} : fresh,
          connectionStatus: state.connectionStatus,
        ),
      );
    } catch (e) {
      if (state.orders == null) {
        emit(
          KdsOrdersError(
            'Не удалось загрузить заказы: $e',
            connectionStatus: state.connectionStatus,
          ),
        );
      }
    }
  }

  List<KdsOrder> _sortedActive(List<KdsOrder> orders) {
    final active = orders.where((o) => o.isActive).toList();
    active.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return active;
  }

  void _startPolling() {
    final interval = pollInterval;
    if (interval == null || _pollTimer != null) return;
    _pollTimer = Timer.periodic(
      interval,
      (_) => add(const KdsOrdersPollTicked()),
    );
  }

  void _startSseSubscription(String branchId) {
    _sseSubscription?.cancel();
    _sseSubscription = repository.watchOrders(branchId).listen(
      (event) => add(KdsOrdersStreamEventReceived(event)),
      onError: (_) {
        if (!isClosed) {
          add(
            const KdsOrdersStreamEventReceived(
              KdsOrdersStreamEvent.disconnected,
            ),
          );
        }
      },
    );
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _sseSubscription?.cancel();
    return super.close();
  }
}
