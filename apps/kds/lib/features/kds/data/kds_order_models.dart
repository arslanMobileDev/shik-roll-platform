import 'package:equatable/equatable.dart';

/// Order lifecycle status (API-702 `OrderEntity.status`).
enum KdsOrderStatus {
  newOrder('NEW'),
  confirmed('CONFIRMED'),
  cooking('COOKING'),
  ready('READY'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  const KdsOrderStatus(this.wireName);

  final String wireName;

  static KdsOrderStatus fromWire(String value) =>
      KdsOrderStatus.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => KdsOrderStatus.newOrder,
      );
}

/// Fulfilment type (API-702 `OrderEntity.type`).
enum KdsOrderType {
  dineIn('DINE_IN'),
  takeaway('TAKEAWAY'),
  delivery('DELIVERY');

  const KdsOrderType(this.wireName);

  final String wireName;

  static KdsOrderType fromWire(String value) => KdsOrderType.values.firstWhere(
    (t) => t.wireName == value,
    orElse: () => KdsOrderType.dineIn,
  );
}

/// Modifier applied to an order line (API-702 `OrderItemModifierEntity`).
final class KdsOrderItemModifier extends Equatable {
  const KdsOrderItemModifier({
    required this.id,
    required this.name,
    required this.quantity,
  });

  final String id;
  final String name;
  final int quantity;

  factory KdsOrderItemModifier.fromJson(Map<String, dynamic> json) =>
      KdsOrderItemModifier(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  @override
  List<Object?> get props => [id, name, quantity];
}

/// Single line of an order (API-702 `OrderItemEntity`).
final class KdsOrderItem extends Equatable {
  const KdsOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.comment,
    this.modifiers = const [],
  });

  final String id;
  final String name;
  final int quantity;
  final String? comment;
  final List<KdsOrderItemModifier> modifiers;

  factory KdsOrderItem.fromJson(Map<String, dynamic> json) => KdsOrderItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    comment: json['comment'] as String?,
    modifiers: [
      for (final m in (json['modifiers'] as List?) ?? const [])
        KdsOrderItemModifier.fromJson(m as Map<String, dynamic>),
    ],
  );

  @override
  List<Object?> get props => [id, name, quantity, comment, modifiers];
}

/// Kitchen-facing order (API-702 `OrderEntity`, trimmed to KDS concerns —
/// money fields are cashier-facing and intentionally not mapped here).
final class KdsOrder extends Equatable {
  const KdsOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.type,
    required this.branchId,
    required this.createdAt,
    this.tableNumber,
    this.comment,
    this.items = const [],
  });

  final String id;
  final String orderNumber;
  final KdsOrderStatus status;
  final KdsOrderType type;
  final String branchId;
  final DateTime createdAt;
  final String? tableNumber;
  final String? comment;
  final List<KdsOrderItem> items;

  /// Kitchen-visible statuses: everything still on the board.
  bool get isActive =>
      status != KdsOrderStatus.completed && status != KdsOrderStatus.cancelled;

  /// «В очереди» column buckets NEW and CONFIRMED together.
  bool get isQueued =>
      status == KdsOrderStatus.newOrder || status == KdsOrderStatus.confirmed;

  KdsOrder copyWith({KdsOrderStatus? status}) => KdsOrder(
    id: id,
    orderNumber: orderNumber,
    status: status ?? this.status,
    type: type,
    branchId: branchId,
    createdAt: createdAt,
    tableNumber: tableNumber,
    comment: comment,
    items: items,
  );

  factory KdsOrder.fromJson(Map<String, dynamic> json) => KdsOrder(
    id: json['id'] as String? ?? '',
    orderNumber: json['orderNumber'] as String? ?? '',
    status: KdsOrderStatus.fromWire(json['status'] as String? ?? 'NEW'),
    type: KdsOrderType.fromWire(json['type'] as String? ?? 'DINE_IN'),
    branchId: json['branchId'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    tableNumber: json['tableNumber'] as String?,
    comment: json['comment'] as String?,
    items: [
      for (final i in (json['items'] as List?) ?? const [])
        KdsOrderItem.fromJson(i as Map<String, dynamic>),
    ],
  );

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    status,
    type,
    branchId,
    createdAt,
    tableNumber,
    comment,
    items,
  ];
}
