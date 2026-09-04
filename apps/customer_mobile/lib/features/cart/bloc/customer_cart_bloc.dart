import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/cart_line.dart';
import 'cart_event.dart';
import 'cart_state.dart';

/// Guest cart: positions with modifiers, quantities and automatic total
/// recalculation. Replaces the placeholder `CartCountCubit`.
class CustomerCartBloc extends Bloc<CartEvent, CartState> {
  CustomerCartBloc() : super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartLineQuantityChanged>(_onQuantityChanged);
    on<CartLineRemoved>(_onLineRemoved);
    on<CartCleared>(_onCleared);
  }

  void _onItemAdded(CartItemAdded event, Emitter<CartState> emit) {
    if (event.quantity <= 0) return;
    final line = CartLine.fromSelection(
      item: event.item,
      selection: event.selection,
      quantity: event.quantity,
    );
    final lines = [...state.lines];
    final index = lines.indexWhere((l) => l.id == line.id);
    if (index >= 0) {
      lines[index] = lines[index].copyWith(
        quantity: lines[index].quantity + event.quantity,
      );
    } else {
      lines.add(line);
    }
    emit(CartState(lines: lines));
  }

  void _onQuantityChanged(
    CartLineQuantityChanged event,
    Emitter<CartState> emit,
  ) {
    final lines = [...state.lines];
    final index = lines.indexWhere((l) => l.id == event.lineId);
    if (index < 0) return;
    final next = lines[index].quantity + event.delta;
    if (next <= 0) {
      lines.removeAt(index);
    } else {
      lines[index] = lines[index].copyWith(quantity: next);
    }
    emit(CartState(lines: lines));
  }

  void _onLineRemoved(CartLineRemoved event, Emitter<CartState> emit) {
    emit(
      CartState(
        lines: [
          for (final line in state.lines)
            if (line.id != event.lineId) line,
        ],
      ),
    );
  }

  void _onCleared(CartCleared event, Emitter<CartState> emit) {
    emit(const CartState());
  }
}
