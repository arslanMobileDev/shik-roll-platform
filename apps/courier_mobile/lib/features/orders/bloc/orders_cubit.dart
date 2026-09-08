import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bloc/bloc.dart';

import '../../../data/models/courier_order.dart';
import '../../../data/models/courier_order_event.dart';
import '../../../data/models/courier_session.dart';
import '../../../data/repositories/courier_repository.dart';
import 'orders_state.dart';

/// Active deliveries of the courier's branch (ADR-1617):
/// REST snapshot -> authorized SSE -> polling fallback.
///
/// * after the initial snapshot an authorized SSE stream is opened;
/// * reconnect uses exponential backoff with jitter, capped at 30 s, and a
///   REST refresh always happens before reconnecting;
/// * after three failed attempts the cubit switches to polling every 30 s
///   (foreground only) while still probing SSE; a recovered stream cancels
///   polling;
/// * an app resume triggers an immediate refresh; pull-to-refresh stays the
///   manual recovery path.
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    required this._repository,
    required this._session,
    Random? jitter,
  }) : _jitter = jitter ?? Random(),
       super(const OrdersLoading());

  final CourierRepository _repository;
  final CourierSession _session;
  final Random _jitter;

  static const _maxSseAttempts = 3;
  static const _pollInterval = Duration(seconds: 30);
  static const _maxBackoff = Duration(seconds: 30);
  static const _eventDedupLimit = 500;

  bool _started = false;
  bool _foreground = true;
  StreamSubscription<CourierOrderEvent>? _sseSub;
  Timer? _refreshDebounce;
  Completer<void>? _foregroundWaiter;

  final Set<String> _seenEventKeys = {};
  final Queue<String> _eventKeyOrder = Queue<String>();

  /// Initial load + realtime loop. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    unawaited(_run());
  }

  /// Full REST snapshot.
  Future<void> refresh() async {
    final current = state;
    if (current is! OrdersLoaded) emit(const OrdersLoading());
    try {
      final orders = await _repository.fetchActiveOrders();
      if (isClosed) return;
      final loaded = current is OrdersLoaded ? current : null;
      emit(
        OrdersLoaded(
          orders: orders,
          courierId: _session.courier.id,
          tab: loaded?.tab ?? OrdersTab.available,
          realtime: loaded?.realtime ?? RealtimeConnectionState.connecting,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      if (current is! OrdersLoaded) {
        emit(const OrdersFailure('Не удалось загрузить заказы'));
      }
    }
  }

  void selectTab(OrdersTab tab) {
    final current = state;
    if (current is OrdersLoaded) emit(current.copyWith(tab: tab));
  }

  /// App lifecycle hook from the view: polling runs only in foreground and
  /// every resume forces an immediate refresh.
  void setForeground(bool value) {
    _foreground = value;
    if (!value || !_started || isClosed) return;
    _foregroundWaiter?.complete();
    _foregroundWaiter = null;
    unawaited(refresh());
  }

  /// «Взять доставку»: claim an unassigned READY order — it optimistically
  /// moves to «Мой активный заказ».
  Future<void> claim(String orderId) => _mutate(
    orderId,
    optimistic: (o) => o.copyWith(courierId: () => _session.courier.id),
    request: () => _repository.claimOrder(orderId),
  );

  /// «В пути»: start the delivery of the own READY order — starts location
  /// tracking (handled by LocationTrackingCubit via the orders listener).
  Future<void> startDelivery(String orderId) => _mutate(
    orderId,
    optimistic: (o) => o.copyWith(status: OrderStatus.onWay),
    request: () => _repository.startDelivery(orderId),
  );

  /// «Доставлен»: finish the own ON_WAY order — it leaves the active list.
  Future<void> completeDelivery(String orderId) => _mutate(
    orderId,
    optimistic: (o) => o.copyWith(status: OrderStatus.completed),
    request: () => _repository.completeDelivery(orderId),
  );

  Future<void> _mutate(
    String orderId, {
    required CourierOrder Function(CourierOrder) optimistic,
    required Future<void> Function() request,
  }) async {
    final current = state;
    if (current is! OrdersLoaded || current.mutatingOrderId != null) return;

    final previous = current.orders;
    final optimisticList = previous
        .map((o) => o.id == orderId ? optimistic(o) : o)
        .where((o) => o.status != OrderStatus.completed)
        .toList();

    emit(
      current.copyWith(orders: optimisticList, mutatingOrderId: () => orderId),
    );
    try {
      await request();
      if (isClosed) return;
      emit(
        current.copyWith(orders: optimisticList, mutatingOrderId: () => null),
      );
    } on CourierOrderConflictException {
      if (isClosed) return;
      await _rollback(current, previous, 'Статус заказа изменился');
    } catch (_) {
      if (isClosed) return;
      await _rollback(current, previous, 'Не удалось обновить статус');
    }
  }

  /// Rollback + immediate refresh after a conflict/network error (ADR-1617).
  Future<void> _rollback(
    OrdersLoaded current,
    List<CourierOrder> previous,
    String message,
  ) async {
    emit(current.copyWith(orders: previous, mutatingOrderId: () => null));
    emit(OrdersFailure(message));
    if (!isClosed) emit(current.copyWith(orders: previous));
    await refresh();
  }

  /// Stops SSE/polling (logout, dispose).
  Future<void> stop() async {
    _started = false;
    _foregroundWaiter?.complete();
    _foregroundWaiter = null;
    _refreshDebounce?.cancel();
    await _sseSub?.cancel();
    _sseSub = null;
  }

  @override
  Future<void> close() async {
    await stop();
    return super.close();
  }

  // ---------------------------------------------------------------------------
  // Realtime: SSE with backoff -> polling fallback (foreground only).
  // ---------------------------------------------------------------------------

  Future<void> _run() async {
    var failures = 0;
    while (_started && !isClosed) {
      _setRealtime(
        failures >= _maxSseAttempts
            ? RealtimeConnectionState.polling
            : RealtimeConnectionState.connecting,
      );

      await _consumeStream(() {
        failures = 0;
        _setRealtime(RealtimeConnectionState.live);
      });
      if (!_started || isClosed) return;
      failures++;

      // After three failed attempts switch to the polling fallback at once —
      // the next iteration's delay IS the 30 s poll interval (ADR-1617).
      // Polling runs only while the app is foregrounded.
      if (failures >= _maxSseAttempts) {
        _setRealtime(RealtimeConnectionState.polling);
        await _waitForeground();
      }
      if (!_started || isClosed) return;

      // Always resync via REST before the next SSE attempt.
      await refresh();
      if (!_started || isClosed) return;
      await _delay(_backoffFor(failures));
    }
  }

  /// Consumes one SSE connection until it ends or errors.
  /// [onFirstEvent] flips the indicator to live and resets the failure count.
  Future<void> _consumeStream(void Function() onFirstEvent) async {
    final done = Completer<void>();
    var firstEvent = true;
    _sseSub = _repository.watchOrders().listen(
      (event) {
        if (firstEvent) {
          firstEvent = false;
          onFirstEvent();
        }
        _applyEvent(event);
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
    await _sseSub?.cancel();
    _sseSub = null;
  }

  void _applyEvent(CourierOrderEvent event) {
    if (isClosed) return;
    if (!_seenEventKeys.add(event.dedupKey)) return;
    _eventKeyOrder.add(event.dedupKey);
    while (_eventKeyOrder.length > _eventDedupLimit) {
      _seenEventKeys.remove(_eventKeyOrder.removeFirst());
    }

    final current = state;
    if (current is! OrdersLoaded) {
      _debouncedRefresh();
      return;
    }
    final index = current.orders.indexWhere((o) => o.id == event.orderId);
    if (index == -1) {
      // Unknown order (new or out of snapshot scope) — resync.
      _debouncedRefresh();
      return;
    }
    final status = OrderStatus.tryFromWire(event.status);
    final next = List<CourierOrder>.of(current.orders);
    if (status == null ||
        !(status == OrderStatus.cooking ||
            status == OrderStatus.ready ||
            status == OrderStatus.onWay)) {
      // Order left the delivery lifecycle (COMPLETED/CANCELLED/unknown).
      next.removeAt(index);
    } else {
      next[index] = next[index].copyWith(
        status: status,
        courierId: () => event.courierId,
      );
    }
    emit(current.copyWith(orders: next));
  }

  void _debouncedRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_started && !isClosed) unawaited(refresh());
    });
  }

  Duration _backoffFor(int failures) {
    if (failures >= _maxSseAttempts) return _pollInterval;
    final exponential = Duration(seconds: 1 << (failures - 1));
    final capped = exponential > _maxBackoff ? _maxBackoff : exponential;
    return capped + Duration(milliseconds: _jitter.nextInt(500));
  }

  Future<void> _waitForeground() async {
    if (_foreground) return;
    _foregroundWaiter ??= Completer<void>();
    await _foregroundWaiter!.future;
  }

  Future<void> _delay(Duration duration) async {
    final timer = Completer<void>();
    Timer(duration, timer.complete);
    await timer.future;
  }

  void _setRealtime(RealtimeConnectionState value) {
    final current = state;
    if (current is OrdersLoaded && current.realtime != value && !isClosed) {
      emit(current.copyWith(realtime: value));
    }
  }
}
