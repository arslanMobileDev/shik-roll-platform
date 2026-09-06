import 'package:equatable/equatable.dart';

import '../../../data/models/courier_order.dart';

/// Which tab of the orders screen is active.
enum OrdersTab {
  /// READY + COOKING — «Доступные к выдаче».
  pickup,

  /// ON_WAY — «Мои в пути».
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

  /// All active (COOKING + READY + ON_WAY) delivery orders of the branch.
  final List<CourierOrder> orders;
  final String courierId;
  final OrdersTab tab;

  /// Order currently being PATCHed (shows spinner on its card).
  final String? updatingOrderId;

  /// READY + COOKING delivery orders — «Доступные к выдаче».
  List<CourierOrder> get pickupOrders => orders
      .where(
        (o) =>
            o.type == OrderType.delivery &&
            (o.status == OrderStatus.ready || o.status == OrderStatus.cooking),
      )
      .toList();

  /// ON_WAY orders assigned to this courier — «Мои в пути».
  List<CourierOrder> get myOrders => orders
      .where(
        (o) =>
            o.type == OrderType.delivery &&
            o.status == OrderStatus.onWay &&
            o.courierId == courierId,
      )
      .toList();

  List<CourierOrder> ordersFor(OrdersTab t) =>
      t == OrdersTab.pickup ? pickupOrders : myOrders;

  OrdersLoaded copyWith({
    List<CourierOrder>? orders,
    OrdersTab? tab,
    String? Function()? updatingOrderId,
  }) => OrdersLoaded(
    orders: orders ?? this.orders,
    courierId: courierId,
    tab: tab ?? this.tab,
    updatingOrderId: updatingOrderId != null
        ? updatingOrderId()
        : this.updatingOrderId,
  );

  @override
  List<Object?> get props => [orders, courierId, tab, updatingOrderId];
}
