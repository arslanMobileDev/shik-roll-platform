import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';
import '../data/cart_line.dart';

/// Snapshot of the guest cart; totals are derived, never stored.
final class CartState extends Equatable {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  /// Sum of quantities across all lines — drives the bottom-nav badge.
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  /// Grand total of the cart in kopeck precision.
  Money get total => lines.fold(Money.zero, (sum, line) => sum + line.total);

  @override
  List<Object?> get props => [lines];
}
