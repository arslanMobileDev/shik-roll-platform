import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';

/// `OrderItemModifierEntity` from openapi.json.
final class OrderHistoryModifier extends Equatable {
  const OrderHistoryModifier({
    required this.modifierItemId,
    required this.name,
    required this.priceDelta,
  });

  factory OrderHistoryModifier.fromJson(Map<String, dynamic> json) {
    try {
      return OrderHistoryModifier(
        modifierItemId: json['modifierItemId'] as String,
        name: json['name'] as String,
        priceDelta: Money.fromRubles((json['priceDelta'] as num?) ?? 0),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed order modifier payload: $e');
    }
  }

  final String modifierItemId;
  final String name;
  final Money priceDelta;

  @override
  List<Object?> get props => [modifierItemId, name, priceDelta];
}

/// `OrderItemEntity` from openapi.json.
final class OrderHistoryItem extends Equatable {
  const OrderHistoryItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.modifiers,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    try {
      return OrderHistoryItem(
        menuItemId: json['menuItemId'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: Money.fromRubles((json['unitPrice'] as num?) ?? 0),
        modifiers: [
          for (final m in (json['modifiers'] as List<dynamic>?) ?? const [])
            OrderHistoryModifier.fromJson(m as Map<String, dynamic>),
        ],
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed order item payload: $e');
    }
  }

  final String menuItemId;
  final String name;
  final int quantity;
  final Money unitPrice;
  final List<OrderHistoryModifier> modifiers;

  /// Small-print modifier list under the dish name (`«Спайси · Унаги»`).
  String get modifiersLabel => modifiers.map((m) => m.name).join(' · ');

  @override
  List<Object?> get props => [menuItemId, name, quantity, unitPrice, modifiers];
}

/// `OrderEntity` from openapi.json, trimmed to what the history list shows.
final class OrderHistoryEntry extends Equatable {
  const OrderHistoryEntry({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.type,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  factory OrderHistoryEntry.fromJson(Map<String, dynamic> json) {
    try {
      final orderNumber = json['orderNumber'];
      if (orderNumber == null) {
        throw const FormatException('Missing orderNumber in order payload');
      }
      return OrderHistoryEntry(
        id: json['id'] as String,
        orderNumber: '$orderNumber',
        status: json['status'] as String? ?? 'NEW',
        type: json['type'] as String? ?? 'DELIVERY',
        totalAmount: Money.fromRubles((json['totalAmount'] as num?) ?? 0),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        items: [
          for (final item in (json['items'] as List<dynamic>?) ?? const [])
            OrderHistoryItem.fromJson(item as Map<String, dynamic>),
        ],
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed order payload: $e');
    }
  }

  final String id;

  /// Human-facing number shown to the guest (`#1042`).
  final String orderNumber;

  /// Backend status (`NEW`, `CONFIRMED`, `COOKING`, `READY`, …).
  final String status;

  /// `DELIVERY` / `TAKEAWAY` / `DINE_IN`.
  final String type;

  final Money totalAmount;
  final DateTime createdAt;
  final List<OrderHistoryItem> items;

  /// Composition preview: `«Филадельфия ×2, Лимонад ×1»`.
  String get itemsLabel =>
      items.map((i) => '${i.name} ×${i.quantity}').join(', ');

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    status,
    type,
    totalAmount,
    createdAt,
    items,
  ];
}
