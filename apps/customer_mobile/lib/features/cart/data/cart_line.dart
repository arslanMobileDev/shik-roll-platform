import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';
import '../../menu/data/menu_models.dart';

/// One position in the guest cart: a menu item with a frozen modifier
/// selection and a quantity.
///
/// Lines are keyed by `item.id` plus the sorted chosen modifier ids, so
/// adding the same dish with the same modifiers merges quantities while a
/// different selection creates a separate line.
final class CartLine extends Equatable {
  const CartLine({
    required this.id,
    required this.item,
    required this.modifiers,
    required this.unitPrice,
    required this.quantity,
  });

  /// Builds a line from a menu item and a modifier selection
  /// (`modifier group id → selected option ids`, see ProductDetailsCubit).
  factory CartLine.fromSelection({
    required MenuItem item,
    Map<String, Set<String>> selection = const {},
    int quantity = 1,
  }) {
    final chosen = <ModifierItem>[
      for (final group in item.modifierGroups)
        for (final option in group.items)
          if ((selection[group.id] ?? const <String>{}).contains(option.id))
            option,
    ];
    final unit = chosen.fold<Money>(item.price, (sum, m) => sum + m.price);
    return CartLine(
      id: '${item.id}|${chosen.map((m) => m.id).join('+')}',
      item: item,
      modifiers: chosen,
      unitPrice: unit,
      quantity: quantity,
    );
  }

  /// Stable identity: menu item id + chosen modifier ids.
  final String id;

  final MenuItem item;

  /// Chosen modifier options, in menu (group) order.
  final List<ModifierItem> modifiers;

  /// Dish price plus modifier surcharges, per one piece.
  final Money unitPrice;

  final int quantity;

  Money get total => unitPrice * quantity;

  /// Small-print modifier list under the dish name (`«Спайси · Унаги»`).
  String get modifiersLabel => modifiers.map((m) => m.name).join(' · ');

  CartLine copyWith({int? quantity}) => CartLine(
    id: id,
    item: item,
    modifiers: modifiers,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
  );

  @override
  List<Object?> get props => [id, item, modifiers, unitPrice, quantity];
}
