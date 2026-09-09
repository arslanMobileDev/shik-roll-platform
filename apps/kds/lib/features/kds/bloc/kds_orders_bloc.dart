import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/kds_order_models.dart';
import '../data/kds_orders_repository.dart';
import '../data/kitchen_events_client.dart';
import 'kds_orders_event.dart';
import 'kds_orders_state.dart';

/// Kitchen board (ADR-1618): snapshot-first loading, live updates over the
/// kitchen SSE stream and kitchen-owned status transitions.
///
/// Recovery contract:
///  * the first state always comes from `GET /kitchen/orders/active`;
///  * on an SSE drop the stream is retried after 1, 2, 5 and 10 seconds;
///  * after [maxConsecutiveFailures] failed attempts the board falls back to
///    snapshot polling every [pollInterval] (15 s in production);
///  * a successful reconnect stops polling, refreshes the snapshot and goes
///    back to live push.
///
/// Status transitions are optimistic: the card moves immediately and blocks
/// until the server answers; on conflict/error the change is rolled back, a
/// snackbar with the backend error code is shown and a snapshot refresh is
/// forced.
class KdsOrdersBloc extends Bloc<KdsOrdersEvent, KdsOrdersState> {
  KdsOrdersBloc({
    required this.repository,
    required this.eventsClient,
    this.pollInterval = const Duration(seconds: 15),
    this.reconnectDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
    this.maxConsecutiveFailures = 3,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       assert(reconnectDelays.isNotEmpty),
       super(const KdsOrdersLoading()) {
    on<KdsOrdersStarted>(_onStarted);
    on<KdsOrdersRefreshed>(_onRefreshed);
    on<KdsOrderStatusChangeRequested>(_onStatusChangeRequested);
    on<KdsOrdersNewOrdersAcknowledged>(_onNewOrdersAcknowledged);
    on<KdsOrdersPollTicked>(_onPollTicked);
    on<KdsStreamSignalReceived>(_onStreamSignalReceived);
    on<KdsStreamDropped>(_onStreamDropped);
    on<KdsStreamReconnectTicked>(_onStreamReconnectTicked);
  }

  final KdsOrdersRepository repository;
  final KitchenEventsClient eventsClient;

  /// Fallback polling cadence while SSE is down; `null` disables it (tests).
  final Duration? pollInterval;

  /// Reconnect schedule; the last delay is reused for later attempts.
  final List<Duration> reconnectDelays;

  /// Failed reconnects before the 15 s polling fallback kicks in.
  final int maxConsecutiveFailures;

  final DateTime Function() _now;

  StreamSubscription<KitchenStreamSignal>? _streamSub;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  int _consecutiveFailures = 0;
  bool _awaitingReconnect = false;

  /// The initial snapshot completed — stream events may mark arrivals fresh.
  bool _initialized = false;

  KdsConnectionStatus _connection = KdsConnectionStatus.connecting;

  /// Ids the board has already shown — the diff against a snapshot marks
  /// newly arrived NEW/CONFIRMED orders for audio/visual feedback.
  final Set<String> _knownOrderIds = {};

  Future<void> _onStarted(
    KdsOrdersStarted event,
    Emitter<KdsOrdersState> emit,
  ) async {
    await _loadSnapshot(emit, showLoading: true, markFresh: false);
    if (emit.isDone) return;
    _connectStream();
  }

  Future<void> _onRefreshed(
    KdsOrdersRefreshed event,
    Emitter<KdsOrdersState> emit,
  ) => _loadSnapshot(
    emit,
    showLoading: state.orders == null,
    markFresh: state.orders != null,
  );

  Future<void> _onPollTicked(
    KdsOrdersPollTicked event,
    Emitter<KdsOrdersState> emit,
  ) => _loadSnapshot(emit, showLoading: false, markFresh: true);

  Future<void> _onStatusChangeRequested(
    KdsOrderStatusChangeRequested event,
    Emitter<KdsOrdersState> emit,
  ) async {
    final current = state;
    if (current is! KdsOrdersLoaded) return;
    final index = current.orders.indexWhere((o) => o.id == event.orderId);
    if (index < 0 || current.mutatingOrderIds.contains(event.orderId)) return;
    final order = current.orders[index];

    // Optimistic: move the card immediately and block it until the answer.
    final optimistic = order.copyWith(
      status: event.status,
      cookingStartedAt: event.status == KdsOrderStatus.cooking
          ? () => _now().add(current.serverClockOffset)
          : null,
      readyAt: event.status == KdsOrderStatus.ready
          ? () => _now().add(current.serverClockOffset)
          : null,
    );
    emit(
      current.copyWith(
        orders: _replaceAt(current.orders, index, optimistic),
        mutatingOrderIds: {...current.mutatingOrderIds, event.orderId},
        actionError: () => null,
      ),
    );

    try {
      final updated = await repository.updateOrderStatus(
        orderId: event.orderId,
        status: event.status,
        expectedVersion: order.version,
        cookId: event.cookId,
        shiftId: event.shiftId,
      );
      final after = state;
      if (after is! KdsOrdersLoaded || emit.isDone) return;
      emit(
        after.copyWith(
          orders: [
            for (final o in after.orders)
              if (o.id == event.orderId) updated else o,
          ],
          mutatingOrderIds: {...after.mutatingOrderIds}..remove(event.orderId),
        ),
      );
    } on Object catch (e) {
      final after = state;
      if (after is! KdsOrdersLoaded || emit.isDone) return;
      emit(
        after.copyWith(
          // Rollback to the pre-mutation card.
          orders: [
            for (final o in after.orders)
              if (o.id == event.orderId) order else o,
          ],
          mutatingOrderIds: {...after.mutatingOrderIds}..remove(event.orderId),
          actionError: () => e is KitchenOrderUpdateException
              ? e.message
              : 'Не удалось обновить статус. Попробуйте снова.',
        ),
      );
      // Conflict/error always forces a snapshot refresh (ADR-1618).
      await _loadSnapshot(emit, showLoading: false, markFresh: false);
    }
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

  Future<void> _onStreamSignalReceived(
    KdsStreamSignalReceived event,
    Emitter<KdsOrdersState> emit,
  ) async {
    switch (event.signal) {
      case KitchenStreamConnected():
        final wasReconnect = _awaitingReconnect;
        _awaitingReconnect = false;
        _consecutiveFailures = 0;
        _stopPolling();
        _setConnection(emit, KdsConnectionStatus.live);
        // After a reconnect the board re-syncs from the snapshot — silently,
        // without new-order alerts for everything already in flight.
        if (wasReconnect) {
          await _loadSnapshot(emit, showLoading: false, markFresh: false);
        }
      case KitchenOrderUpserted(:final order, :final orderVersion):
        final current = state;
        if (current is! KdsOrdersLoaded) return;
        final index = current.orders.indexWhere((o) => o.id == order.id);
        // Version dedupe: apply only events newer than the local copy.
        if (index >= 0 && current.orders[index].version >= orderVersion) {
          return;
        }
        final isNewArrival = index < 0;
        final fresh = {...current.freshOrderIds};
        if (isNewArrival &&
            _initialized &&
            _isNewKitchenOrder(order.status) &&
            !_knownOrderIds.contains(order.id)) {
          fresh.add(order.id);
        }
        _knownOrderIds.add(order.id);
        final next = isNewArrival
            ? [...current.orders, order]
            : _replaceAt(current.orders, index, order);
        emit(
          current.copyWith(
            orders: _sortedActive(next),
            freshOrderIds: fresh,
            lastUpdatedAt: _now(),
          ),
        );
      case KitchenOrderRemoved(:final orderId):
        final current = state;
        if (current is! KdsOrdersLoaded) return;
        if (current.orders.every((o) => o.id != orderId)) return;
        emit(
          current.copyWith(
            orders: [
              for (final o in current.orders)
                if (o.id != orderId) o,
            ],
            lastUpdatedAt: _now(),
          ),
        );
      case KitchenStreamHeartbeat(:final serverTime):
        final current = state;
        if (current is! KdsOrdersLoaded) return;
        final offset = serverTime.difference(_now());
        if ((offset - current.serverClockOffset).abs() >
            const Duration(seconds: 2)) {
          emit(current.copyWith(serverClockOffset: offset));
        }
    }
  }

  void _onStreamDropped(KdsStreamDropped event, Emitter<KdsOrdersState> emit) {
    _awaitingReconnect = true;
    _consecutiveFailures++;
    _setConnection(emit, KdsConnectionStatus.connecting);
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      _startPolling(emit);
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      _backoffFor(_consecutiveFailures),
      () => add(const KdsStreamReconnectTicked()),
    );
  }

  void _onStreamReconnectTicked(
    KdsStreamReconnectTicked event,
    Emitter<KdsOrdersState> emit,
  ) {
    _connectStream();
  }

  Duration _backoffFor(int attempt) {
    final index = (attempt - 1).clamp(0, reconnectDelays.length - 1);
    return reconnectDelays[index];
  }

  void _connectStream() {
    _streamSub?.cancel();
    // While the polling fallback is active a background redial must not flip
    // the board back to "connecting" — only a successful Connected signal
    // (→ live) changes the visible status.
    if (_connection != KdsConnectionStatus.polling) {
      _connection = KdsConnectionStatus.connecting;
    }
    // No state emission here: the connecting status is already reflected by
    // _onStreamDropped (reconnect path) or the initial load (start path).
    _streamSub = eventsClient.connect().listen(
      (signal) => add(KdsStreamSignalReceived(signal)),
      onError: (_) => add(const KdsStreamDropped()),
      onDone: () => add(const KdsStreamDropped()),
    );
  }

  void _startPolling(Emitter<KdsOrdersState> emit) {
    final interval = pollInterval;
    if (interval == null || _pollTimer != null) return;
    _pollTimer = Timer.periodic(
      interval,
      (_) => add(const KdsOrdersPollTicked()),
    );
    _setConnection(emit, KdsConnectionStatus.polling);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _setConnection(Emitter<KdsOrdersState> emit, KdsConnectionStatus next) {
    _connection = next;
    final current = state;
    if (current is KdsOrdersLoaded && current.connection != next) {
      emit(current.copyWith(connection: next));
    }
  }

  Future<void> _loadSnapshot(
    Emitter<KdsOrdersState> emit, {
    required bool showLoading,
    required bool markFresh,
  }) async {
    if (showLoading) emit(const KdsOrdersLoading());
    try {
      final snapshot = await repository.fetchSnapshot();
      if (emit.isDone) return;
      final orders = _sortedActive(snapshot.orders);

      final fresh = <String>{};
      if (markFresh && _initialized) {
        for (final order in orders) {
          if (!_knownOrderIds.contains(order.id) &&
              _isNewKitchenOrder(order.status)) {
            fresh.add(order.id);
          }
        }
      }
      _knownOrderIds
        ..clear()
        ..addAll(orders.map((o) => o.id));
      _initialized = true;

      final current = state;
      // Unacknowledged highlights survive refreshes (a later poll tick must
      // not wipe them); ids no longer on the board are dropped.
      final orderIds = orders.map((o) => o.id).toSet();
      final mergedFresh = {
        if (current is KdsOrdersLoaded) ...current.freshOrderIds,
        ...fresh,
      }..retainWhere(orderIds.contains);
      emit(
        KdsOrdersLoaded(
          orders: orders,
          lastUpdatedAt: _now(),
          freshOrderIds: mergedFresh,
          connection: _connection,
          mutatingOrderIds: current is KdsOrdersLoaded
              ? current.mutatingOrderIds
              : const {},
          // A refresh (incl. the forced one after a conflict) must not wipe
          // an action error before the snackbar had a chance to show it.
          actionError: current is KdsOrdersLoaded ? current.actionError : null,
          serverClockOffset: snapshot.serverTime.difference(_now()),
        ),
      );
    } on Object catch (e) {
      // A snapshot failure with data on screen must not blank the board;
      // only a failed initial load surfaces the Error state.
      if (state.orders == null && !emit.isDone) {
        emit(KdsOrdersError('Не удалось загрузить заказы: $e'));
      }
    }
  }

  /// Kitchen board shows active orders oldest-first (FIFO by the moment an
  /// order entered its current status).
  List<KdsOrder> _sortedActive(List<KdsOrder> orders) {
    final active = orders.where((o) => o.isActive).toList();
    active.sort((a, b) {
      final byStatus = a.statusSince.compareTo(b.statusSince);
      if (byStatus != 0) return byStatus;
      return a.confirmedAt.compareTo(b.confirmedAt);
    });
    return active;
  }

  List<KdsOrder> _replaceAt(List<KdsOrder> orders, int index, KdsOrder next) =>
      [...orders]..[index] = next;

  bool _isNewKitchenOrder(KdsOrderStatus status) =>
      status == KdsOrderStatus.newOrder || status == KdsOrderStatus.confirmed;

  @override
  Future<void> close() {
    _streamSub?.cancel();
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    return super.close();
  }
}
