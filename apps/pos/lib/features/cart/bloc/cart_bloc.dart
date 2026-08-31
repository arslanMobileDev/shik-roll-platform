import 'package:flutter_bloc/flutter_bloc.dart';

import '../../orders/data/create_order_request.dart';
import '../../orders/data/orders_repository.dart';
import '../domain/cart_line.dart';
import 'cart_event.dart';
import 'cart_state.dart';

/// Cashier cart: items, modifier configurations, quantities and totals.
///
/// All money math is exact decimal (integer kopecks via [Money]); the bloc
/// holds the only source of truth for the order being built and submits it
/// to the Orders API on checkout.
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({required this.ordersRepository}) : super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartLineQuantityChanged>(_onQuantityChanged);
    on<CartLineRemoved>(_onLineRemoved);
    on<CartCleared>(_onCleared);
    on<CheckoutSubmitted>(_onCheckoutSubmitted);
    on<CheckoutFeedbackConsumed>(_onFeedbackConsumed);
  }

  /// Orders API access used by [CheckoutSubmitted].
  final OrdersRepository ordersRepository;

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

  Future<void> _onCheckoutSubmitted(
    CheckoutSubmitted event,
    Emitter<CartState> emit,
  ) async {
    if (state.isEmpty || state.isCheckoutInProgress) return;
    emit(state.copyWith(checkoutStatus: CheckoutStatus.inProgress));
    try {
      final order = await ordersRepository.createOrder(
        CreateOrderRequest(
          branchId: event.branchId,
          orderType: event.orderType,
          tableNumber: event.tableNumber,
          comment: event.comment,
          items: [
            for (final line in state.lines)
              OrderItemRequest(
                menuItemId: line.itemId,
                quantity: line.quantity,
                selectedModifiers: [
                  for (final modifier in line.modifiers)
                    SelectedModifierRequest(modifierItemId: modifier.optionId),
                ],
              ),
          ],
        ),
      );
      // Success clears the cart; the order number is kept for the
      // confirmation dialog.
      emit(
        CartState(
          checkoutStatus: CheckoutStatus.success,
          completedOrder: order,
        ),
      );
    } on OrdersException catch (e) {
      emit(
        state.copyWith(
          checkoutStatus: CheckoutStatus.failure,
          checkoutError: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          checkoutStatus: CheckoutStatus.failure,
          checkoutError: 'Не удалось отправить заказ. Попробуйте ещё раз.',
        ),
      );
    }
  }

  void _onFeedbackConsumed(
    CheckoutFeedbackConsumed event,
    Emitter<CartState> emit,
  ) {
    emit(
      state.copyWith(
        checkoutStatus: CheckoutStatus.idle,
        completedOrder: null,
        checkoutError: null,
      ),
    );
  }

  void _removeLine(String lineKey, Emitter<CartState> emit) {
    emit(
      state.copyWith(
        lines: state.lines.where((l) => l.key != lineKey).toList(),
      ),
    );
  }
}
