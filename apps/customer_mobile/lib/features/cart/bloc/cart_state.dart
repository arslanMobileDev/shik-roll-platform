import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';
import '../data/cart_line.dart';

/// Snapshot of the guest cart; totals are derived, never stored.
final class CartState extends Equatable {
  const CartState({
    this.lines = const [],
    this.deliveryFee = Money.zero,
    this.errorMessage,
  });

  final List<CartLine> lines;

  /// Delivery surcharge; zero for pickup or while the fee is unknown.
  final Money deliveryFee;

  /// Last cart-level failure (e.g. a rejected promo or a stale position).
  /// Nullable: reset via `copyWith(clearError: true)`, never by passing
  /// `errorMessage: null` — a null argument keeps the previous value.
  final String? errorMessage;

  bool get isEmpty => lines.isEmpty;

  /// Sum of quantities across all lines — drives the bottom-nav badge.
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  /// Grand total of the cart in kopeck precision.
  Money get total => lines.fold(Money.zero, (sum, line) => sum + line.total);

  /// Amount the guest actually pays: positions plus the delivery fee.
  Money get finalAmount => total + deliveryFee;

  CartState copyWith({
    List<CartLine>? lines,
    Money? deliveryFee,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [lines, deliveryFee, errorMessage];
}
