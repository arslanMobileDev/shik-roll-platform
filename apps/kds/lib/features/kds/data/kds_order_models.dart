import 'package:equatable/equatable.dart';

/// Order lifecycle status on the kitchen board (API-709 `KitchenOrderStatus`).
///
/// The kitchen API only ever serves CONFIRMED/COOKING/READY; the remaining
/// values exist so removal events and optimistic transitions stay typed.
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
        orElse: () => KdsOrderStatus.confirmed,
      );
}

/// Fulfilment type (API-709 `KitchenOrderDto.type`).
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

/// Modifier applied to an order line (API-709 `KitchenOrderItemDto.modifiers`).
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

/// Single line of an order (API-709 `KitchenOrderItemDto`).
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

DateTime _parseServerTime(String? value, {DateTime? fallback}) =>
    DateTime.tryParse(value ?? '')?.toLocal() ??
    fallback ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// Kitchen-facing order (API-709 `KitchenOrderDto`).
///
/// The DTO intentionally carries no customer phone/address and no payment
/// data. Timestamps are server-stamped: [confirmedAt] when the order entered
/// the board, [cookingStartedAt]/[readyAt] on kitchen transitions.
final class KdsOrder extends Equatable {
  const KdsOrder({
    required this.id,
    required this.orderNumber,
    required this.version,
    required this.status,
    required this.type,
    required this.confirmedAt,
    this.cookingStartedAt,
    this.readyAt,
    this.tableNumber,
    this.comment,
    this.items = const [],
  });

  final String id;
  final String orderNumber;

  /// Optimistic-concurrency version — echoed as `expectedVersion` on status
  /// transitions (API-709 `PATCH /kitchen/orders/{id}/status`).
  final int version;
  final KdsOrderStatus status;
  final KdsOrderType type;

  /// Server timestamp of entering CONFIRMED (board arrival).
  final DateTime confirmedAt;

  /// Server timestamp of the CONFIRMED → COOKING transition, if it happened.
  final DateTime? cookingStartedAt;

  /// Server timestamp of the COOKING → READY transition, if it happened.
  final DateTime? readyAt;

  final String? tableNumber;
  final String? comment;
  final List<KdsOrderItem> items;

  /// Kitchen-visible statuses: everything still on the board.
  bool get isActive =>
      status == KdsOrderStatus.confirmed ||
      status == KdsOrderStatus.cooking ||
      status == KdsOrderStatus.ready;

  /// Moment the order entered its current status (server clock). Drives the
  /// per-column delay timer and the FIFO order inside a column.
  DateTime get statusSince => switch (status) {
    KdsOrderStatus.cooking => cookingStartedAt ?? confirmedAt,
    KdsOrderStatus.ready => readyAt ?? cookingStartedAt ?? confirmedAt,
    _ => confirmedAt,
  };

  KdsOrder copyWith({
    KdsOrderStatus? status,
    int? version,
    DateTime? confirmedAt,
    DateTime? Function()? cookingStartedAt,
    DateTime? Function()? readyAt,
  }) => KdsOrder(
    id: id,
    orderNumber: orderNumber,
    version: version ?? this.version,
    status: status ?? this.status,
    type: type,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    cookingStartedAt: cookingStartedAt != null
        ? cookingStartedAt()
        : this.cookingStartedAt,
    readyAt: readyAt != null ? readyAt() : this.readyAt,
    tableNumber: tableNumber,
    comment: comment,
    items: items,
  );

  factory KdsOrder.fromJson(Map<String, dynamic> json) => KdsOrder(
    id: json['id'] as String? ?? '',
    orderNumber: json['orderNumber'] as String? ?? '',
    version: (json['version'] as num?)?.toInt() ?? 1,
    status: KdsOrderStatus.fromWire(json['status'] as String? ?? 'CONFIRMED'),
    type: KdsOrderType.fromWire(json['type'] as String? ?? 'DINE_IN'),
    confirmedAt: _parseServerTime(json['confirmedAt'] as String?),
    cookingStartedAt: json['cookingStartedAt'] == null
        ? null
        : _parseServerTime(json['cookingStartedAt'] as String?),
    readyAt: json['readyAt'] == null
        ? null
        : _parseServerTime(json['readyAt'] as String?),
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
    version,
    status,
    type,
    confirmedAt,
    cookingStartedAt,
    readyAt,
    tableNumber,
    comment,
    items,
  ];
}
