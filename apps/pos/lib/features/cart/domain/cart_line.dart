import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';
import '../../catalog/data/catalog_models.dart';

/// One chosen modifier option attached to a cart line.
final class SelectedModifier extends Equatable {
  const SelectedModifier({
    required this.groupId,
    required this.groupName,
    required this.optionId,
    required this.optionName,
    required this.price,
  });

  final String groupId;
  final String groupName;
  final String optionId;
  final String optionName;
  final Money price;

  @override
  List<Object?> get props => [groupId, groupName, optionId, optionName, price];
}

/// A line in the cashier's cart: one menu item configuration + quantity.
final class CartLine extends Equatable {
  const CartLine({
    required this.key,
    required this.itemId,
    required this.sku,
    required this.name,
    required this.basePrice,
    required this.currency,
    required this.modifiers,
    required this.quantity,
  });

  /// Builds a line from a catalog item and the chosen modifiers.
  factory CartLine.fromItem({
    required MenuItem item,
    required List<SelectedModifier> modifiers,
    int quantity = 1,
  }) {
    final sorted = [...modifiers]
      ..sort((a, b) => a.optionId.compareTo(b.optionId));
    return CartLine(
      key: _lineKey(item.id, sorted),
      itemId: item.id,
      sku: item.sku,
      name: item.name,
      basePrice: item.price.effective,
      currency: item.price.currency,
      modifiers: List.unmodifiable(sorted),
      quantity: quantity,
    );
  }

  /// Same item + same modifier set collapse into one line.
  static String _lineKey(String itemId, List<SelectedModifier> modifiers) {
    final optionIds = modifiers.map((m) => m.optionId).join('|');
    return '$itemId#$optionIds';
  }

  /// Deterministic identity of the configuration (item + modifiers).
  final String key;
  final String itemId;
  final String sku;
  final String name;
  final Money basePrice;
  final String currency;
  final List<SelectedModifier> modifiers;
  final int quantity;

  /// Unit price = effective catalog price + modifier surcharges.
  Money get unitPrice =>
      modifiers.fold(basePrice, (sum, m) => sum + m.price);

  Money get total => unitPrice * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(
      key: key,
      itemId: itemId,
      sku: sku,
      name: name,
      basePrice: basePrice,
      currency: currency,
      modifiers: modifiers,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [
    key,
    itemId,
    sku,
    name,
    basePrice,
    currency,
    modifiers,
    quantity,
  ];
}
