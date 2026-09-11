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

/// Редактируемые поля формы чекаута: адрес, комментарий, согласие с офертой,
/// способ оплаты и переключатель списания бонусов. Форма переживает смену фаз
/// [CheckoutState] (ADR-001): после сетевой ошибки введённые данные не теряются.
final class CheckoutForm extends Equatable {
  const CheckoutForm({
    this.address = '',
    this.comment = '',
    this.offerAccepted = false,
    this.paymentMethod = PaymentMethod.online,
    this.bonusSpendEnabled = false,
  });

  final String address;
  final String comment;
  final bool offerAccepted;

  /// Выбранный способ оплаты; по умолчанию — онлайн-эквайринг ЮKassa.
  final PaymentMethod paymentMethod;

  /// «Списать бонусы» (ADR-1614): при включении чекаут уходит с
  /// `useBonusPoints`, рассчитанным по балансу и лимиту 30% от чека.
  final bool bonusSpendEnabled;

  CheckoutForm copyWith({
    String? address,
    String? comment,
    bool? offerAccepted,
    PaymentMethod? paymentMethod,
    bool? bonusSpendEnabled,
  }) {
    return CheckoutForm(
      address: address ?? this.address,
      comment: comment ?? this.comment,
      offerAccepted: offerAccepted ?? this.offerAccepted,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bonusSpendEnabled: bonusSpendEnabled ?? this.bonusSpendEnabled,
    );
  }

  @override
  List<Object?> get props => [
    address,
    comment,
    offerAccepted,
    paymentMethod,
    bonusSpendEnabled,
  ];
}

/// Фазы жизненного цикла чекаута (ADR-001, sealed вместо flat state):
/// редактирование → отправка → успех | ошибка. Невозможные комбинации
/// («лоадер поверх ошибки», «протухшая ошибка при retry») исключены на
/// уровне компилятора; навигация и SnackBar — одноразовые эффекты через
/// `BlocListener` на терминальные состояния, не часть формы.
sealed class CheckoutState extends Equatable {
  const CheckoutState({this.form = const CheckoutForm()});

  final CheckoutForm form;

  // Прокси к полям формы: виджеты читают их, не зная о [CheckoutForm].
  String get address => form.address;
  String get comment => form.comment;
  bool get offerAccepted => form.offerAccepted;
  PaymentMethod get paymentMethod => form.paymentMethod;
  bool get bonusSpendEnabled => form.bonusSpendEnabled;

  /// The «Оформить заказ» button is enabled only when the cart has lines,
  /// the offer is accepted and — for delivery — the address is filled.
  /// Пока идёт отправка ([CheckoutSubmitting]) повторный submit невозможен —
  /// это и есть droppable-семантика защиты от double-tap (ADR-001).
  bool canSubmit({required OrderType orderType, required bool cartIsEmpty}) {
    if (this is CheckoutSubmitting || cartIsEmpty || !offerAccepted) {
      return false;
    }
    if (orderType == OrderType.delivery && address.trim().isEmpty) {
      return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [form];
}

/// Форма открыта и редактируется (начальная фаза и фаза после `reset`).
final class CheckoutEditing extends CheckoutState {
  const CheckoutEditing({super.form});
}

/// Заказ отправляется на сервер; UI показывает лоадер, кнопка заблокирована.
final class CheckoutSubmitting extends CheckoutState {
  const CheckoutSubmitting({super.form});
}

/// Заказ принят. Терминальная одноразовая фаза: экран потребляет её
/// (навигация через `BlocListener`) и вызывает [CheckoutCubit.reset].
final class CheckoutSuccess extends CheckoutState {
  const CheckoutSuccess({super.form, required this.placedOrder, this.payment});

  final GuestOrder placedOrder;

  /// Платёж ЮKassa, созданный вслед за заказом при оплате онлайн; `null` для
  /// наличной/терминальной оплаты (ON_DELIVERY → заказ NEW без редиректа).
  final Payment? payment;

  @override
  List<Object?> get props => [form, placedOrder, payment];
}

/// Ошибка оформления. Форма сохранена в [form], гость может повторить
/// отправку; сообщение показывается одноразовым SnackBar'ом в `BlocListener`.
final class CheckoutFailure extends CheckoutState {
  const CheckoutFailure({super.form, required this.errorMessage});

  final String errorMessage;

  @override
  List<Object?> get props => [form, errorMessage];
}

/// Sends the guest order through [CustomerOrdersRepository]. For ONLINE
/// orders the same `POST /orders` response contains the YooKassa redirect;
/// checkout does not create a duplicate payment session.
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this._repository,
    required CustomerPaymentsRepository paymentsRepository,
    String? brandId,
    String? branchId,
  }) : _brandId = brandId ?? AppConfig.defaultBrandId,
       _branchId = branchId ?? AppConfig.defaultBranchId,
       super(const CheckoutEditing());

  final CustomerOrdersRepository _repository;
  final String _brandId;
  final String _branchId;

  void addressChanged(String value) =>
      emit(CheckoutEditing(form: state.form.copyWith(address: value)));

  void commentChanged(String value) =>
      emit(CheckoutEditing(form: state.form.copyWith(comment: value)));

  void offerToggled(bool accepted) =>
      emit(CheckoutEditing(form: state.form.copyWith(offerAccepted: accepted)));

  void paymentMethodSelected(PaymentMethod method) =>
      emit(CheckoutEditing(form: state.form.copyWith(paymentMethod: method)));

  /// «Списать бонусы» переключатель корзины (ADR-1614).
  void bonusSpendToggled(bool enabled) => emit(
    CheckoutEditing(form: state.form.copyWith(bonusSpendEnabled: enabled)),
  );

  Future<void> submit({
    required OrderType orderType,
    required List<CartLine> lines,

    /// Бонусы к списанию (`useBonusPoints`, ADR-1614), уже усечённые до
    /// `min(balance, floor(30% от чека))` на экране. Игнорируется, когда
    /// переключатель списания выключен. Сервер повторно проверяет лимит.
    int bonusPoints = 0,
  }) async {
    // Guard от double-tap (ADR-001): в Cubit нет event transformers, поэтому
    // droppable-семантика реализована синхронной проверкой — повторный вызов
    // до завершения текущего (state is CheckoutSubmitting) отбрасывается до
    // первого await, race condition в однопоточном event loop исключён.
    if (!state.canSubmit(orderType: orderType, cartIsEmpty: lines.isEmpty)) {
      return;
    }
    // Свежая фаза submitting: предыдущая ошибка и consumed-success
    // уничтожаются сменой типа состояния, протухших полей не остаётся.
    emit(CheckoutSubmitting(form: state.form));
    try {
      final order = await _repository.createOrder(
        _buildRequest(orderType, lines, bonusPoints),
      );
      final payment = state.paymentMethod == PaymentMethod.online
          ? _paymentFromOrder(order)
          : null;
      emit(
        CheckoutSuccess(form: state.form, placedOrder: order, payment: payment),
      );
    } on OrdersException catch (e) {
      emit(CheckoutFailure(form: state.form, errorMessage: e.message));
    }
  }

  /// Back to a blank form after the success was consumed.
  void reset() => emit(const CheckoutEditing());

  CreateOrderRequest _buildRequest(
    OrderType orderType,
    List<CartLine> lines,
    int bonusPoints,
  ) {
    final address = state.address.trim();
    final comment = state.comment.trim();
    return CreateOrderRequest(
      brandId: _brandId,
      branchId: _branchId,
      orderType: orderType,
      paymentMethod: state.paymentMethod,
      deliveryAddress: orderType == OrderType.delivery ? address : null,
      comment: comment.isEmpty ? null : comment,
      useBonusPoints: state.bonusSpendEnabled ? bonusPoints : 0,
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

  Payment _paymentFromOrder(GuestOrder order) {
    final url = Uri.tryParse(order.paymentUrl ?? '');
    if (url == null ||
        !url.hasScheme ||
        (url.scheme != 'https' && url.scheme != 'http') ||
        url.host.isEmpty) {
      throw const OrdersException(
        'Сервер не вернул ссылку на онлайн-оплату. Попробуйте ещё раз.',
      );
    }
    return Payment(
      id: order.paymentId ?? order.id,
      paymentUrl: url.toString(),
      status: PaymentStatus.pending,
    );
  }
}
