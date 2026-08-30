import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/cart_line.dart';
import 'cart_event.dart';
import 'cart_state.dart';

/// Cashier cart: items, modifier configurations, quantities and totals.
///
/// All money math is exact decimal (integer kopecks via [Money]); the bloc
/// holds the only source of truth for the order being built.
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartLineQuantityChanged>(_onQuantityChanged);
    on<CartLineRemoved>(_onLineRemoved);
    on<CartCleared>(_onCleared);
  }

  void _onItemAdded(CartItemAdded event, Emitter<CartState> emit) {
    if (!event.item.available || event.quantity <= 0) return;

    final line = CartLine.fromItem(
      item: event.item,
      modifiers: event.modifiers,
      quantity: event.quantity,
    );
    final existing = state.lines.indexWhere((l) => l.key == line.key);
    if (existing >= 0) {
      final updated = [...state.lines];
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + event.quantity,
      );
      emit(state.copyWith(lines: updated));
    } else {
      emit(state.copyWith(lines: [...state.lines, line]));
    }
  }

  void _onQuantityChanged(
    CartLineQuantityChanged event,
    Emitter<CartState> emit,
  ) {
    if (event.quantity <= 0) {
      _removeLine(event.lineKey, emit);
      return;
    }
    final index = state.lines.indexWhere((l) => l.key == event.lineKey);
    if (index < 0) return;
    final updated = [...state.lines];
    updated[index] = updated[index].copyWith(quantity: event.quantity);
    emit(state.copyWith(lines: updated));
  }

  void _onLineRemoved(CartLineRemoved event, Emitter<CartState> emit) {
    _removeLine(event.lineKey, emit);
  }

  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    emit(const CartState());
  }

  void _removeLine(String lineKey, Emitter<CartState> emit) {
    emit(
      state.copyWith(
        lines: state.lines.where((l) => l.key != lineKey).toList(),
      ),
    );
  }
}
