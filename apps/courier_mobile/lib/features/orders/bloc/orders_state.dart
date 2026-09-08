import 'package:equatable/equatable.dart';

import '../../../data/models/courier_order.dart';

/// Вкладки экрана заказов (ADR-1617).
enum OrdersTab {
  /// «Доступные заказы филиала» — неназначенные delivery в COOKING/READY.
  available,

  /// «Мой активный заказ» — собственный заказ в READY или ON_WAY.
  mine,
}

/// Состояние realtime-подключения (SSE / polling fallback).
enum RealtimeConnectionState {
  /// SSE (пере)подключается.
  connecting,

  /// SSE live.
  live,

  /// SSE недоступен — polling каждые 30 секунд в foreground.
  polling,
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
    this.tab = OrdersTab.available,
    this.mutatingOrderId,
    this.realtime = RealtimeConnectionState.connecting,
  });

  /// All active (COOKING + READY + ON_WAY) delivery orders of the branch.
  final List<CourierOrder> orders;
  final String courierId;
  final OrdersTab tab;

  /// Order currently being mutated (its buttons are blocked).
  final String? mutatingOrderId;

  /// SSE/polling connection indicator state.
  final RealtimeConnectionState realtime;

  /// «Доступные заказы филиала»: unassigned delivery orders in
  /// COOKING or READY; claim is allowed only for READY.
  List<CourierOrder> get availableOrders => orders
      .where(
        (o) =>
            o.type == OrderType.delivery &&
            o.courierId == null &&
            (o.status == OrderStatus.ready || o.status == OrderStatus.cooking),
      )
      .toList();

  /// «Мой активный заказ»: own assigned order in READY or ON_WAY.
  List<CourierOrder> get myOrders => orders
      .where(
        (o) =>
            o.type == OrderType.delivery &&
            o.courierId == courierId &&
            (o.status == OrderStatus.ready || o.status == OrderStatus.onWay),
      )
      .toList();

  /// Own order currently out for delivery — drives location tracking.
  CourierOrder? get myOnWayOrder {
    for (final order in myOrders) {
      if (order.status == OrderStatus.onWay) return order;
    }
    return null;
  }

  List<CourierOrder> ordersFor(OrdersTab t) =>
      t == OrdersTab.available ? availableOrders : myOrders;

  OrdersLoaded copyWith({
    List<CourierOrder>? orders,
    OrdersTab? tab,
    String? Function()? mutatingOrderId,
    RealtimeConnectionState? realtime,
  }) => OrdersLoaded(
    orders: orders ?? this.orders,
    courierId: courierId,
    tab: tab ?? this.tab,
    mutatingOrderId: mutatingOrderId != null
        ? mutatingOrderId()
        : this.mutatingOrderId,
    realtime: realtime ?? this.realtime,
  );

  @override
  List<Object?> get props => [orders, courierId, tab, mutatingOrderId, realtime];
}
