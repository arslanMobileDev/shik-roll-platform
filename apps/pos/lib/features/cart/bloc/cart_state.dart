import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';
import '../domain/cart_line.dart';

final class CartState extends Equatable {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  /// Grand total in RUB, exact decimal math via minor units.
  Money get total => lines.fold(Money.zero, (sum, l) => sum + l.total);

  bool get isEmpty => lines.isEmpty;

  CartState copyWith({List<CartLine>? lines}) =>
      CartState(lines: lines ?? this.lines);

  @override
  List<Object?> get props => [lines];
}
