import 'package:equatable/equatable.dart';

import '../../../data/models/courier_order.dart';

/// Which tab of the orders screen is active.
enum OrdersTab {
  /// READY — «К забору с кухни».
  pickup,

  /// DELIVERING — «Мои текущие».
  mine,
}

sealed class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object?> get props => [];
}

final class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

final class OrdersFailure extends OrdersState {
  const OrdersFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class OrdersLoaded extends OrdersState {
  const OrdersLoaded({
    required this.orders,
    required this.courierId,
    this.tab = OrdersTab.pickup,
    this.updatingOrderId,
  });

  /// All active (READY + DELIVERING) orders of the branch.
  final List<CourierOrder> orders;
  final String courierId;
  final OrdersTab tab;

  /// Order currently being PATCHed (shows spinner on its card).
  final String? updatingOrderId;

  /// READY orders — «К забору с кухни».
  List<CourierOrder> get pickupOrders =>
      orders.where((o) => o.status == OrderStatus.ready).toList();

  /// DELIVERING orders assigned to this courier — «Мои текущие».
  List<CourierOrder> get myOrders => orders
      .where(
        (o) => o.status == OrderStatus.delivering && o.courierId == courierId,
      )
      .toList();

  List<CourierOrder> ordersFor(OrdersTab t) =>
      t == OrdersTab.pickup ? pickupOrders : myOrders;

  OrdersLoaded copyWith({
    List<CourierOrder>? orders,
    OrdersTab? tab,
    String? Function()? updatingOrderId,
  }) =>
      OrdersLoaded(
        orders: orders ?? this.orders,
        courierId: courierId,
        tab: tab ?? this.tab,
        updatingOrderId:
            updatingOrderId != null ? updatingOrderId() : this.updatingOrderId,
      );

  @override
  List<Object?> get props => [orders, courierId, tab, updatingOrderId];
}
