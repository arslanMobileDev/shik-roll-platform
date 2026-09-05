import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

/// Order lifecycle statuses (openapi OrderEntity.status).
enum OrderStatus {
  newOrder('NEW', 'Новый'),
  confirmed('CONFIRMED', 'Подтверждён'),
  cooking('COOKING', 'Готовится'),
  ready('READY', 'Готов'),
  completed('COMPLETED', 'Завершён'),
  cancelled('CANCELLED', 'Отменён');

  const OrderStatus(this.wireName, this.label);

  /// Contract value used in query params and payloads.
  final String wireName;
  final String label;

  static OrderStatus fromJson(String value) => OrderStatus.values.firstWhere(
    (s) => s.wireName == value,
    orElse: () => OrderStatus.newOrder,
  );
}

/// Order fulfilment type (openapi OrderEntity.type).
enum OrderType {
  dineIn('DINE_IN', 'В зале'),
  takeaway('TAKEAWAY', 'С собой'),
  delivery('DELIVERY', 'Доставка');

  const OrderType(this.wireName, this.label);

  final String wireName;
  final String label;

  static OrderType fromJson(String value) => OrderType.values.firstWhere(
    (t) => t.wireName == value,
    orElse: () => OrderType.takeaway,
  );
}

/// A modifier applied to an order line (openapi OrderItemModifierEntity).
final class OrderItemModifier extends Equatable {
  const OrderItemModifier({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.quantity,
  });

  final String id;
  final String name;
  final Money priceDelta;
  final int quantity;

  factory OrderItemModifier.fromJson(Map<String, dynamic> json) =>
      OrderItemModifier(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        priceDelta: _moneyFrom(json['priceDelta']),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  @override
  List<Object?> get props => [id, name, priceDelta, quantity];
}

/// A single receipt line (openapi OrderItemEntity).
final class OrderItem extends Equatable {
  const OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.comment,
    this.modifiers = const [],
  });

  final String id;
  final String menuItemId;
  final String name;
  final int quantity;
  final Money unitPrice;
  final Money totalAmount;
  final String? comment;
  final List<OrderItemModifier> modifiers;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'] as String? ?? '',
    menuItemId: json['menuItemId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: _moneyFrom(json['unitPrice']),
    totalAmount: _moneyFrom(json['totalAmount']),
    comment: json['comment'] as String?,
    modifiers:
        (json['modifiers'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(OrderItemModifier.fromJson)
            .toList(growable: false) ??
        const [],
  );

  @override
  List<Object?> get props => [
    id,
    menuItemId,
    name,
    quantity,
    unitPrice,
    totalAmount,
    comment,
    modifiers,
  ];
}

/// A customer order as returned by `GET /orders` (openapi OrderEntity).
final class Order extends Equatable {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.type,
    required this.brandId,
    required this.branchId,
    required this.subtotalAmount,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    this.tableNumber,
    this.deliveryAddress,
    this.comment,
    this.estimatedReadyAt,
    this.completedAt,
    this.cancelledAt,
    this.items = const [],
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final OrderType type;
  final String brandId;
  final String branchId;
  final Money subtotalAmount;
  final Money totalAmount;
  final String currency;
  final DateTime createdAt;
  final String? tableNumber;
  final String? deliveryAddress;
  final String? comment;
  final DateTime? estimatedReadyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final List<OrderItem> items;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String? ?? '',
    orderNumber: json['orderNumber'] as String? ?? '',
    status: OrderStatus.fromJson(json['status'] as String? ?? ''),
    type: OrderType.fromJson(json['type'] as String? ?? ''),
    brandId: json['brandId'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    subtotalAmount: _moneyFrom(json['subtotalAmount']),
    totalAmount: _moneyFrom(json['totalAmount']),
    currency: json['currency'] as String? ?? 'RUB',
    createdAt: _dateFrom(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    tableNumber: json['tableNumber'] as String?,
    deliveryAddress: json['deliveryAddress'] as String?,
    comment: json['comment'] as String?,
    estimatedReadyAt: _dateFrom(json['estimatedReadyAt']),
    completedAt: _dateFrom(json['completedAt']),
    cancelledAt: _dateFrom(json['cancelledAt']),
    items:
        (json['items'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(OrderItem.fromJson)
            .toList(growable: false) ??
        const [],
  );

  /// Short receipt summary for table rows, e.g. `3 поз.`.
  String get itemsSummary => '${items.fold<int>(0, (sum, i) => sum + i.quantity)} поз.';

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    status,
    type,
    brandId,
    branchId,
    subtotalAmount,
    totalAmount,
    currency,
    createdAt,
    tableNumber,
    deliveryAddress,
    comment,
    estimatedReadyAt,
    completedAt,
    cancelledAt,
    items,
  ];
}

/// One page of the orders journal (openapi OrderPage + PageMeta).
final class OrdersPage extends Equatable {
  const OrdersPage({
    required this.orders,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Order> orders;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory OrdersPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return OrdersPage(
      orders:
          (json['data'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(Order.fromJson)
              .toList(growable: false) ??
          const [],
      page: (meta['page'] as num?)?.toInt() ?? 1,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [orders, page, totalPages, total];
}

/// Contract amounts are RUB major units (openapi `*Amount: number`).
Money _moneyFrom(Object? value) => switch (value) {
  final num rubles => Money.fromRubles(rubles.toDouble()),
  _ => Money.zero,
};

DateTime? _dateFrom(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
