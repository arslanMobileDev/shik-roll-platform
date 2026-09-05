import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/kds_order_models.dart';
import '../data/kds_orders_repository.dart';
import 'kds_orders_event.dart';
import 'kds_orders_state.dart';

/// Kitchen board: active orders for a branch with periodic polling.
///
/// The bloc owns all board logic — fetching, FIFO sorting, new-order
/// detection and status transitions. Widgets only render state and dispatch
/// events.
class KdsOrdersBloc extends Bloc<KdsOrdersEvent, KdsOrdersState> {
  KdsOrdersBloc({
    required this.repository,
    this.pollInterval = const Duration(seconds: 10),
  }) : super(const KdsOrdersLoading()) {
    on<KdsOrdersStarted>(_onStarted);
    on<KdsOrdersRefreshed>(_onRefreshed);
    on<KdsOrdersPollTicked>(_onPollTicked);
    on<KdsOrderStatusChangeRequested>(_onStatusChangeRequested);
    on<KdsOrdersNewOrdersAcknowledged>(_onNewOrdersAcknowledged);
  }

  final KdsOrdersRepository repository;

  /// Polling cadence; `null` disables polling (widget tests).
  final Duration? pollInterval;

  Timer? _pollTimer;
  String? _branchId;

  /// Ids the board has already shown — the diff against a fresh fetch marks
  /// newly arrived orders for audio/visual feedback.
  final Set<String> _seenOrderIds = {};

  Future<void> _onStarted(
    KdsOrdersStarted event,
    Emitter<KdsOrdersState> emit,
  ) async {
    _branchId = event.branchId;
    _startPolling();
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
      KdsOrdersActionInProgress(orders: current, pendingOrderId: event.orderId),
    );
    try {
      await repository.updateOrderStatus(
        orderId: event.orderId,
        status: event.status,
        cookId: event.cookId,
        shiftId: event.shiftId,
      );
      // Refetch: the server is the single source of truth and other stations
      // may have moved orders concurrently.
      await _load(emit, showLoading: false);
    } catch (e) {
      emit(
        KdsOrdersLoaded(
          orders: current,
          lastUpdatedAt: DateTime.now(),
          actionError: 'Не удалось обновить статус: $e',
        ),
      );
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

  Future<void> _load(
    Emitter<KdsOrdersState> emit, {
    required bool showLoading,
  }) async {
    final branchId = _branchId;
    if (branchId == null) return;
    if (showLoading) emit(const KdsOrdersLoading());

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

      // A poll failure with data on screen must not blank the board; only a
      // failed initial load surfaces the Error state.
      emit(
        KdsOrdersLoaded(
          orders: orders,
          lastUpdatedAt: DateTime.now(),
          freshOrderIds: state.orders == null ? const {} : fresh,
        ),
      );
    } catch (e) {
      if (state.orders == null) {
        emit(KdsOrdersError('Не удалось загрузить заказы: $e'));
      }
    }
  }

  /// Kitchen board shows active orders oldest-first (FIFO).
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

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
