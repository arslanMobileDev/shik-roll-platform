import 'package:equatable/equatable.dart';

import '../../menu/bloc/order_type.dart';
import '../../payments/data/payment_method.dart';

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
    this.paymentMethod = PaymentMethod.online,
    this.deliveryAddress,
    this.comment,
    this.useBonusPoints = 0,
  });

  final String branchId;
  final OrderType orderType;
  final List<OrderItemRequest> items;
  final PaymentMethod paymentMethod;

  /// Expected when [orderType] is [OrderType.delivery].
  final String? deliveryAddress;
  final String? comment;

  /// Bonus points to spend (ADR-1614): integer, 1 point = 1 RUB, max 30% of
  /// the item amount. Omitted from the payload when zero.
  final int useBonusPoints;

  Map<String, dynamic> toJson() => {
    'branchId': branchId,
    'brandId': '37b84f4c-0a70-4263-bfa0-cc04ba0d4b99',
    'type': orderType.wireName,
    'paymentMethod': paymentMethod.wireName,
    if (deliveryAddress != null && deliveryAddress!.isNotEmpty)
      'deliveryAddress': deliveryAddress,
    if (comment != null && comment!.isNotEmpty) 'comment': comment,
    if (useBonusPoints > 0) 'useBonusPoints': useBonusPoints,
    'items': [for (final item in items) item.toJson()],
  };

  @override
  List<Object?> get props => [
    branchId,
    orderType,
    items,
    paymentMethod,
    deliveryAddress,
    comment,
    useBonusPoints,
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
    'modifiers': [for (final m in selectedModifiers) m.toJson()],
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
