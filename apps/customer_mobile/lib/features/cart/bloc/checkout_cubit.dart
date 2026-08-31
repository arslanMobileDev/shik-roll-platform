import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/app_config.dart';
import '../../menu/bloc/order_type.dart';
import '../data/cart_line.dart';
import '../data/create_order_request.dart';
import '../data/guest_order.dart';
import '../data/orders_repository.dart';

enum CheckoutStatus { editing, submitting, success, failure }

/// Checkout form state: address, comment, offer consent and the submission
/// lifecycle. Validation rules live here (see [CheckoutState.canSubmit]);
/// widgets only render and forward edits.
final class CheckoutState extends Equatable {
  const CheckoutState({
    this.address = '',
    this.comment = '',
    this.offerAccepted = false,
    this.status = CheckoutStatus.editing,
    this.errorMessage,
    this.placedOrder,
  });

  final String address;
  final String comment;
  final bool offerAccepted;
  final CheckoutStatus status;
  final String? errorMessage;

  /// Set for exactly one emission after a successful checkout; the screen
  /// consumes it (navigation) and calls [CheckoutCubit.reset].
  final GuestOrder? placedOrder;

  /// The «Оформить заказ» button is enabled only when the cart has lines,
  /// the offer is accepted and — for delivery — the address is filled.
  bool canSubmit({required OrderType orderType, required bool cartIsEmpty}) {
    if (status == CheckoutStatus.submitting || cartIsEmpty || !offerAccepted) {
      return false;
    }
    if (orderType == OrderType.delivery && address.trim().isEmpty) {
      return false;
    }
    return true;
  }

  CheckoutState copyWith({
    String? address,
    String? comment,
    bool? offerAccepted,
    CheckoutStatus? status,
    String? errorMessage,
    GuestOrder? placedOrder,
  }) {
    return CheckoutState(
      address: address ?? this.address,
      comment: comment ?? this.comment,
      offerAccepted: offerAccepted ?? this.offerAccepted,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      placedOrder: placedOrder ?? this.placedOrder,
    );
  }

  @override
  List<Object?> get props => [
    address,
    comment,
    offerAccepted,
    status,
    errorMessage,
    placedOrder,
  ];
}

/// Sends the guest order through [CustomerOrdersRepository].
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({required this._repository}) : super(const CheckoutState());

  final CustomerOrdersRepository _repository;

  void addressChanged(String value) =>
      emit(state.copyWith(address: value, status: CheckoutStatus.editing));

  void commentChanged(String value) =>
      emit(state.copyWith(comment: value, status: CheckoutStatus.editing));

  void offerToggled(bool accepted) => emit(
    state.copyWith(offerAccepted: accepted, status: CheckoutStatus.editing),
  );

  Future<void> submit({
    required OrderType orderType,
    required List<CartLine> lines,
  }) async {
    if (!state.canSubmit(orderType: orderType, cartIsEmpty: lines.isEmpty)) {
      return;
    }
    // Fresh state: clears a previous error and the consumed placedOrder.
    emit(
      CheckoutState(
        address: state.address,
        comment: state.comment,
        offerAccepted: state.offerAccepted,
        status: CheckoutStatus.submitting,
      ),
    );
    try {
      final order = await _repository.createOrder(
        _buildRequest(orderType, lines),
      );
      emit(state.copyWith(status: CheckoutStatus.success, placedOrder: order));
    } on OrdersException catch (e) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }

  /// Back to a blank form after the success was consumed.
  void reset() => emit(const CheckoutState());

  CreateOrderRequest _buildRequest(OrderType orderType, List<CartLine> lines) {
    final address = state.address.trim();
    final comment = state.comment.trim();
    return CreateOrderRequest(
      branchId: AppConfig.defaultBranchId,
      orderType: orderType,
      deliveryAddress: orderType == OrderType.delivery ? address : null,
      comment: comment.isEmpty ? null : comment,
      items: [
        for (final line in lines)
          OrderItemRequest(
            menuItemId: line.item.id,
            quantity: line.quantity,
            selectedModifiers: [
              for (final modifier in line.modifiers)
                SelectedModifierRequest(modifierItemId: modifier.id),
            ],
          ),
      ],
    );
  }
}
