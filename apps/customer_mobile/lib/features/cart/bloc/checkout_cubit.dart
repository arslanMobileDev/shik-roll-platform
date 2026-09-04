import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/app_config.dart';
import '../../menu/bloc/order_type.dart';
import '../../payments/data/payment.dart';
import '../../payments/data/payment_method.dart';
import '../../payments/data/payments_repository.dart';
import '../data/cart_line.dart';
import '../data/create_order_request.dart';
import '../data/guest_order.dart';
import '../data/orders_repository.dart';

enum CheckoutStatus { editing, submitting, success, failure }

/// Checkout form state: address, comment, offer consent, payment method and
/// the submission lifecycle. Validation rules live here (see
/// [CheckoutState.canSubmit]); widgets only render and forward edits.
final class CheckoutState extends Equatable {
  const CheckoutState({
    this.address = '',
    this.comment = '',
    this.offerAccepted = false,
    this.paymentMethod = PaymentMethod.yookassa,
    this.status = CheckoutStatus.editing,
    this.errorMessage,
    this.placedOrder,
    this.payment,
  });

  final String address;
  final String comment;
  final bool offerAccepted;

  /// Выбранный способ оплаты; по умолчанию — онлайн-эквайринг ЮKassa.
  final PaymentMethod paymentMethod;

  final CheckoutStatus status;
  final String? errorMessage;

  /// Set for exactly one emission after a successful checkout; the screen
  /// consumes it (navigation) and calls [CheckoutCubit.reset].
  final GuestOrder? placedOrder;

  /// Платёж ЮKassa, созданный вслед за заказом при оплате онлайн; `null` для
  /// наличной/терминальной оплаты. Одноразовый, как [placedOrder].
  final Payment? payment;

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
    PaymentMethod? paymentMethod,
    CheckoutStatus? status,
    String? errorMessage,
    GuestOrder? placedOrder,
    Payment? payment,
  }) {
    return CheckoutState(
      address: address ?? this.address,
      comment: comment ?? this.comment,
      offerAccepted: offerAccepted ?? this.offerAccepted,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      placedOrder: placedOrder ?? this.placedOrder,
      payment: payment ?? this.payment,
    );
  }

  @override
  List<Object?> get props => [
    address,
    comment,
    offerAccepted,
    paymentMethod,
    status,
    errorMessage,
    placedOrder,
    payment,
  ];
}

/// Sends the guest order through [CustomerOrdersRepository]; for online
/// payment additionally creates a YooKassa payment via
/// [CustomerPaymentsRepository] (`POST /payments/create`, API-702).
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this._repository,
    required this._paymentsRepository,
  }) : super(const CheckoutState());

  final CustomerOrdersRepository _repository;
  final CustomerPaymentsRepository _paymentsRepository;

  void addressChanged(String value) =>
      emit(state.copyWith(address: value, status: CheckoutStatus.editing));

  void commentChanged(String value) =>
      emit(state.copyWith(comment: value, status: CheckoutStatus.editing));

  void offerToggled(bool accepted) => emit(
    state.copyWith(offerAccepted: accepted, status: CheckoutStatus.editing),
  );

  void paymentMethodSelected(PaymentMethod method) => emit(
    state.copyWith(paymentMethod: method, status: CheckoutStatus.editing),
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
        paymentMethod: state.paymentMethod,
        status: CheckoutStatus.submitting,
      ),
    );
    try {
      final order = await _repository.createOrder(
        _buildRequest(orderType, lines),
      );
      // Онлайн-оплата: сразу после создания заказа выставляем счёт в ЮKassa.
      final payment = switch (state.paymentMethod) {
        PaymentMethod.yookassa => await _paymentsRepository.createPayment(
          order.id,
        ),
        _ => null,
      };
      emit(
        state.copyWith(
          status: CheckoutStatus.success,
          placedOrder: order,
          payment: payment,
        ),
      );
    } on OrdersException catch (e) {
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: e.message,
        ),
      );
    } on PaymentsException catch (e) {
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
