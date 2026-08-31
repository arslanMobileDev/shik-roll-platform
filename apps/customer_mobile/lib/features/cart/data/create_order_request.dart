import 'package:equatable/equatable.dart';

import '../../menu/bloc/order_type.dart';

/// Wire mapping for the guest order type (`POST /orders` contract).
extension OrderTypeWire on OrderType {
  String get wireName => switch (this) {
    OrderType.delivery => 'DELIVERY',
    OrderType.pickup => 'TAKEAWAY',
  };
}

/// `POST /orders` payload for the guest checkout.
///
/// Mirrors the POS `CreateOrderRequest` contract
/// (apps/pos/lib/features/orders/data/create_order_request.dart); cross-app
/// imports are not possible, so the customer app carries its own copy
/// extended with [deliveryAddress].
final class CreateOrderRequest extends Equatable {
  const CreateOrderRequest({
    required this.branchId,
    required this.orderType,
    required this.items,
    this.deliveryAddress,
    this.comment,
  });

  final String branchId;
  final OrderType orderType;
  final List<OrderItemRequest> items;

  /// Expected when [orderType] is [OrderType.delivery].
  final String? deliveryAddress;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'branchId': branchId,
    'orderType': orderType.wireName,
    if (deliveryAddress != null && deliveryAddress!.isNotEmpty)
      'deliveryAddress': deliveryAddress,
    if (comment != null && comment!.isNotEmpty) 'comment': comment,
    'items': [for (final item in items) item.toJson()],
  };

  @override
  List<Object?> get props => [
    branchId,
    orderType,
    items,
    deliveryAddress,
    comment,
  ];
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
  const SelectedModifierRequest({required this.modifierItemId, this.quantity = 1});

  final String modifierItemId;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'modifierItemId': modifierItemId,
    'quantity': quantity,
  };

  @override
  List<Object?> get props => [modifierItemId, quantity];
}
