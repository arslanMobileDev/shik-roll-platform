import 'package:equatable/equatable.dart';

import '../../catalog/data/catalog_models.dart';
import '../../orders/domain/order_entity.dart';
import '../domain/cart_line.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

/// Adds an item (with the chosen modifiers) to the cart.
final class CartItemAdded extends CartEvent {
  const CartItemAdded({
    required this.item,
    this.modifiers = const [],
    this.quantity = 1,
  });

  final MenuItem item;
  final List<SelectedModifier> modifiers;
  final int quantity;

  @override
  List<Object?> get props => [item, modifiers, quantity];
}

/// Sets the quantity of an existing line; 0 removes the line.
final class CartLineQuantityChanged extends CartEvent {
  const CartLineQuantityChanged(this.lineKey, this.quantity);

  final String lineKey;
  final int quantity;

  @override
  List<Object?> get props => [lineKey, quantity];
}

final class CartLineRemoved extends CartEvent {
  const CartLineRemoved(this.lineKey);

  final String lineKey;

  @override
  List<Object?> get props => [lineKey];
}

final class CartCleared extends CartEvent {
  const CartCleared();
}

/// Submits the current cart to the Orders API (`POST /orders`).
final class CheckoutSubmitted extends CartEvent {
  const CheckoutSubmitted({
    required this.branchId,
    required this.orderType,
    this.tableNumber,
    this.comment,
  });

  final String branchId;
  final OrderType orderType;

  /// Table label for [OrderType.dineIn] orders.
  final String? tableNumber;
  final String? comment;

  @override
  List<Object?> get props => [branchId, orderType, tableNumber, comment];
}

/// Resets checkout feedback (success dialog dismissed / error snackbar
/// shown) back to [CheckoutStatus.idle].
final class CheckoutFeedbackConsumed extends CartEvent {
  const CheckoutFeedbackConsumed();
}
