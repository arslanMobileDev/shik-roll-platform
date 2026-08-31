import 'package:equatable/equatable.dart';

import '../domain/order_entity.dart';

/// `POST /orders` payload (Orders API contract).
final class CreateOrderRequest extends Equatable {
  const CreateOrderRequest({
    required this.branchId,
    required this.orderType,
    required this.items,
    this.tableNumber,
    this.comment,
  });

  final String branchId;
  final OrderType orderType;
  final List<OrderItemRequest> items;

  /// Table label; expected when [orderType] is [OrderType.dineIn].
  final String? tableNumber;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'branchId': branchId,
    'orderType': orderType.wireName,
    if (tableNumber != null) 'tableNumber': tableNumber,
    if (comment != null && comment!.isNotEmpty) 'comment': comment,
    'items': [for (final item in items) item.toJson()],
  };

  @override
  List<Object?> get props => [branchId, orderType, items, tableNumber, comment];
}

/// One line of [CreateOrderRequest]: a menu item plus its modifiers.
final class OrderItemRequest extends Equatable {
  const OrderItemRequest({
    required this.menuItemId,
    required this.quantity,
    this.selectedModifiers = const [],
  });

  final String menuItemId;
  final int quantity;
  final List<SelectedModifierRequest> selectedModifiers;

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'quantity': quantity,
    'selectedModifiers': [for (final m in selectedModifiers) m.toJson()],
  };

  @override
  List<Object?> get props => [menuItemId, quantity, selectedModifiers];
}

/// One chosen modifier option inside an [OrderItemRequest].
final class SelectedModifierRequest extends Equatable {
  const SelectedModifierRequest({
    required this.modifierItemId,
    this.quantity = 1,
  });

  final String modifierItemId;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'modifierItemId': modifierItemId,
    'quantity': quantity,
  };

  @override
  List<Object?> get props => [modifierItemId, quantity];
}
