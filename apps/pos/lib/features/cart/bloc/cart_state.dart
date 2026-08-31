import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';
import '../../orders/domain/order_entity.dart';
import '../domain/cart_line.dart';

/// Lifecycle of the checkout round-trip to the Orders API.
enum CheckoutStatus { idle, inProgress, success, failure }

final class CartState extends Equatable {
  const CartState({
    this.lines = const [],
    this.checkoutStatus = CheckoutStatus.idle,
    this.completedOrder,
    this.checkoutError,
  });

  final List<CartLine> lines;

  /// Checkout progress; drives the button spinner, dialog and snackbar.
  final CheckoutStatus checkoutStatus;

  /// The order created by the latest successful checkout.
  final OrderEntity? completedOrder;

  /// Human-readable message of the latest failed checkout.
  final String? checkoutError;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  /// Grand total in RUB, exact decimal math via minor units.
  Money get total => lines.fold(Money.zero, (sum, l) => sum + l.total);

  bool get isEmpty => lines.isEmpty;

  bool get isCheckoutInProgress => checkoutStatus == CheckoutStatus.inProgress;

  CartState copyWith({
    List<CartLine>? lines,
    CheckoutStatus? checkoutStatus,
    Object? completedOrder = _unset,
    Object? checkoutError = _unset,
  }) => CartState(
    lines: lines ?? this.lines,
    checkoutStatus: checkoutStatus ?? this.checkoutStatus,
    completedOrder: identical(completedOrder, _unset)
        ? this.completedOrder
        : completedOrder as OrderEntity?,
    checkoutError: identical(checkoutError, _unset)
        ? this.checkoutError
        : checkoutError as String?,
  );

  static const Object _unset = Object();

  @override
  List<Object?> get props => [
    lines,
    checkoutStatus,
    completedOrder,
    checkoutError,
  ];
}
