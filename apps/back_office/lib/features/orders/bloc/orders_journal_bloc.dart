import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/orders_repository.dart';
import 'orders_journal_event.dart';
import 'orders_journal_state.dart';

/// Loads the orders journal and applies status / period filters.
///
/// The status filter is server-side (contract query param), the period
/// filter is client-side over loaded pages (no date params in the API).
final class OrdersJournalBloc
    extends Bloc<OrdersJournalEvent, OrdersJournalState> {
  OrdersJournalBloc({required this._repository})
    : super(const OrdersJournalState()) {
    on<OrdersJournalRequested>(_onRequested);
    on<OrdersStatusFilterChanged>(_onStatusFilterChanged);
    on<OrdersDateFilterChanged>(_onDateFilterChanged);
    on<OrdersJournalNextPageRequested>(_onNextPageRequested);
    on<OrderDetailsOpened>(_onDetailsOpened);
    on<OrderDetailsClosed>(_onDetailsClosed);
    on<OrdersJournalNoticeConsumed>(_onNoticeConsumed);
  }

  final OrdersRepository _repository;

  Future<void> _loadFirstPage(Emitter<OrdersJournalState> emit) async {
    try {
      final result = await _repository.fetchOrders(
        branchId: state.branchId,
        status: state.statusFilter,
      );
      emit(
        state.copyWith(
          status: OrdersJournalStatus.ready,
          orders: result.orders,
          page: result.page,
          totalPages: result.totalPages,
          total: result.total,
        ),
      );
    } on Object catch (e) {
      emit(
        state.copyWith(
          status: OrdersJournalStatus.failure,
          errorMessage: 'Не удалось загрузить заказы: $e',
        ),
      );
    }
  }

  Future<void> _onRequested(
    OrdersJournalRequested event,
    Emitter<OrdersJournalState> emit,
  ) async {
    emit(
      state.copyWith(
        status: OrdersJournalStatus.loading,
        branchId: event.branchId,
        clearError: true,
        clearNotice: true,
        clearSelection: true,
        clearPayment: true,
      ),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onStatusFilterChanged(
    OrdersStatusFilterChanged event,
    Emitter<OrdersJournalState> emit,
  ) async {
    if (event.status == state.statusFilter) return;
    emit(
      state.copyWith(
        status: OrdersJournalStatus.loading,
        statusFilter: event.status,
        clearStatusFilter: event.status == null,
        clearError: true,
      ),
    );
    await _loadFirstPage(emit);
  }

  void _onDateFilterChanged(
    OrdersDateFilterChanged event,
    Emitter<OrdersJournalState> emit,
  ) {
    emit(
      state.copyWith(
        dateFilter: event.filter,
        customDay: event.customDay,
        clearCustomDay: event.customDay == null,
      ),
    );
  }

  Future<void> _onNextPageRequested(
    OrdersJournalNextPageRequested event,
    Emitter<OrdersJournalState> emit,
  ) async {
    if (state.status != OrdersJournalStatus.ready ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true, clearNotice: true));
    try {
      final result = await _repository.fetchOrders(
        branchId: state.branchId,
        status: state.statusFilter,
        page: state.page + 1,
      );
      final knownIds = state.orders.map((o) => o.id).toSet();
      emit(
        state.copyWith(
          isLoadingMore: false,
          orders: [
            ...state.orders,
            ...result.orders.where((o) => !knownIds.contains(o.id)),
          ],
          page: result.page,
          totalPages: result.totalPages,
          total: result.total,
        ),
      );
    } on Object catch (e) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          notice: 'Не удалось загрузить ещё заказы: $e',
        ),
      );
    }
  }

  Future<void> _onDetailsOpened(
    OrderDetailsOpened event,
    Emitter<OrdersJournalState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedOrderId: event.orderId,
        paymentStatus: OrderPaymentStatus.loading,
        clearPayment: true,
      ),
    );
    try {
      final payment = await _repository.fetchOrderPayment(
        orderId: event.orderId,
      );
      // The dialog may have been closed (or reopened for another order)
      // while the payment was loading.
      if (state.selectedOrderId != event.orderId) return;
      emit(
        state.copyWith(
          paymentStatus: OrderPaymentStatus.ready,
          payment: payment,
          clearPayment: payment == null,
        ),
      );
    } on Object catch (_) {
      if (state.selectedOrderId != event.orderId) return;
      emit(state.copyWith(paymentStatus: OrderPaymentStatus.failure));
    }
  }

  void _onDetailsClosed(
    OrderDetailsClosed event,
    Emitter<OrdersJournalState> emit,
  ) {
    emit(
      state.copyWith(
        clearSelection: true,
        clearPayment: true,
        paymentStatus: OrderPaymentStatus.idle,
      ),
    );
  }

  void _onNoticeConsumed(
    OrdersJournalNoticeConsumed event,
    Emitter<OrdersJournalState> emit,
  ) {
    emit(state.copyWith(clearNotice: true));
  }
}
