import 'package:equatable/equatable.dart';

import '../../menu/data/menu_models.dart';

/// Commands accepted by [CustomerCartBloc].
sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

/// Adds a dish with the selected modifiers; merging into an existing line
/// when the same dish + modifiers combination is already in the cart.
final class CartItemAdded extends CartEvent {
  const CartItemAdded({required this.item, this.selection = const {}});

  final MenuItem item;

  /// Modifier group id → selected option ids (may be empty for plain dishes).
  final Map<String, Set<String>> selection;

  @override
  List<Object?> get props => [item, selection];
}

/// Adjusts a line quantity by [delta] (`+1` / `-1`); reaching zero removes
/// the line.
final class CartLineQuantityChanged extends CartEvent {
  const CartLineQuantityChanged({required this.lineId, required this.delta});

  final String lineId;
  final int delta;

  @override
  List<Object?> get props => [lineId, delta];
}

/// Drops a position from the cart regardless of its quantity.
final class CartLineRemoved extends CartEvent {
  const CartLineRemoved({required this.lineId});

  final String lineId;

  @override
  List<Object?> get props => [lineId];
}

/// Empties the cart (after a successful checkout or by guest action).
final class CartCleared extends CartEvent {
  const CartCleared();
}
