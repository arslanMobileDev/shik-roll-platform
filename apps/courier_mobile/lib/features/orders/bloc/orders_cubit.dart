// ignore_for_file: prefer_initializing_formals
// Named public parameters initialize private fields by design.
import 'package:bloc/bloc.dart';

import '../../../data/models/courier_order.dart';
import '../../../data/models/courier_session.dart';
import '../../../data/repositories/courier_repository.dart';
import 'orders_state.dart';

/// Active deliveries for the courier's branch.
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    required CourierRepository repository,
    required CourierSession session,
  })  : _repository = repository,
        _session = session,
        super(const OrdersLoading());

  final CourierRepository _repository;
  final CourierSession _session;

  Future<void> load() async {
    emit(const OrdersLoading());
    try {
      final orders = await _repository.fetchActiveOrders(
        branchId: _session.branch.id,
      );
      emit(OrdersLoaded(orders: orders, courierId: _session.courier.id));
    } catch (_) {
      emit(const OrdersFailure('Не удалось загрузить заказы'));
    }
  }

  void selectTab(OrdersTab tab) {
    final current = state;
    if (current is OrdersLoaded) {
      emit(current.copyWith(tab: tab));
    }
  }

  /// READY -> DELIVERING («Забрал заказ»), one tap.
  Future<void> pickupOrder(String orderId) =>
      _setStatus(orderId, OrderStatus.delivering);

  /// DELIVERING -> COMPLETED («Доставлено»).
  Future<void> completeOrder(String orderId) =>
      _setStatus(orderId, OrderStatus.completed);

  Future<void> _setStatus(String orderId, OrderStatus status) async {
    final current = state;
    if (current is! OrdersLoaded || current.updatingOrderId != null) return;

    final previous = current.orders;
    final optimistic = previous
        .map(
          (o) => o.id == orderId
              ? o.copyWith(status: status, courierId: _session.courier.id)
              : o,
        )
        .where((o) => o.status != OrderStatus.completed)
        .toList();

    emit(current.copyWith(orders: optimistic, updatingOrderId: () => orderId));
    try {
      await _repository.updateOrderStatus(
        orderId: orderId,
        status: status,
        courierId: _session.courier.id,
      );
      emit(current.copyWith(orders: optimistic, updatingOrderId: () => null));
    } catch (_) {
      emit(current.copyWith(
        orders: previous,
        updatingOrderId: () => null,
      ));
      emit(const OrdersFailure('Не удалось обновить статус'));
      emit(current.copyWith(orders: previous));
    }
  }
}
