import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/view/auth_flow.dart';
import '../../legal/data/legal_document.dart';
import '../../legal/view/legal_document_viewer_screen.dart';
import '../../loyalty/bloc/loyalty_cubit.dart';
import '../../loyalty/view/bonus_spend_section.dart';
import '../../menu/bloc/order_type.dart';
import '../../menu/view/widgets/order_type_toggle.dart';
import '../../orders/data/order_tracking_repository.dart';
import '../../orders/presentation/screens/order_tracking_screen.dart';
import '../../payments/view/payment_status_screen.dart';
import '../../payments/view/widgets/payment_method_selector.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';
import '../bloc/checkout_cubit.dart';
import '../bloc/customer_cart_bloc.dart';
import 'widgets/cart_empty_view.dart';
import 'widgets/cart_item_tile.dart';
import 'widgets/delivery_address_form.dart';
import 'widgets/delivery_time_selector.dart';

/// Guest cart tab: positions with modifiers, delivery/pickup switch,
/// address & comment, offer consent and the checkout button.
class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.onGoToMenu,
    required this.orderTrackingRepository,
    this.paymentUrlLauncher = launchExternalPaymentUrl,
  });

  /// Switches the shell back to the menu tab.
  final VoidCallback onGoToMenu;
  final OrderTrackingRepository orderTrackingRepository;
  final PaymentUrlLauncher paymentUrlLauncher;

  @override
  Widget build(BuildContext context) {
    // Одноразовые эффекты (ADR-001): навигация и SnackBar реагируют только на
    // смену фазы; редактирование формы внутри одной фазы listener не будит.
    return BlocListener<CheckoutCubit, CheckoutState>(
      listenWhen: (previous, next) => previous.runtimeType != next.runtimeType,
      listener: (context, state) {
        switch (state) {
          case CheckoutSuccess(:final placedOrder, :final payment):
            final cart = context.read<CustomerCartBloc>().state;
            final loyaltyCubit = context.read<LoyaltyCubit>();
            final orderType = context.read<OrderTypeCubit>().state;
            context.read<CheckoutCubit>().reset();
            context.read<CustomerCartBloc>().add(const CartCleared());
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => payment != null
                    ? PaymentStatusScreen(
                        order: placedOrder,
                        payment: payment,
                        trackingRepository: orderTrackingRepository,
                        loyaltyCubit: loyaltyCubit,
                        onBackToMenu: onGoToMenu,
                        urlLauncher: paymentUrlLauncher,
                      )
                    : OrderTrackingScreen(
                        orderId: placedOrder.id,
                        orderNumber: placedOrder.orderNumber,
                        trackingRepository: orderTrackingRepository,
                        deliveryAddress: orderType == OrderType.delivery
                            ? state.composedAddress
                            : null,
                        items: [
                          for (final line in cart.lines)
                            {
                              'name': line.item.name,
                              'count': line.quantity,
                              'price': line.total.rubles,
                            },
                        ],
                        totalPrice: cart.total.rubles,
                        loyaltyCubit: loyaltyCubit,
                      ),
              ),
            );
          case CheckoutFailure(:final errorMessage):
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(errorMessage)));
          case CheckoutEditing() || CheckoutSubmitting():
            break;
        }
      },
      child: BlocBuilder<CustomerCartBloc, CartState>(
        builder: (context, cart) {
          if (cart.isEmpty) return CartEmptyView(onGoToMenu: onGoToMenu);
          return _CartContent(cart: cart);
        },
      ),
    );
  }
}

class _CartContent extends StatelessWidget {
  const _CartContent({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderType = context.watch<OrderTypeCubit>().state;
    final checkout = context.watch<CheckoutCubit>().state;
    final loyalty = context.watch<LoyaltyCubit>().state;
    final submitting = checkout is CheckoutSubmitting;
    final canSubmit = checkout.canSubmit(
      orderType: orderType,
      cartIsEmpty: cart.isEmpty,
    );
    // Превью списания (ADR-1614): до min(баланс, floor(30% от чека)) бонусов;
    // сервер повторно проверит лимит при оформлении.
    final appliedBonusPoints = checkout.bonusSpendEnabled
        ? loyalty.maxSpendablePoints(cart.total)
        : 0;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              children: [
                const SizedBox(height: AppSpacing.s8),
                Text('Корзина', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.s12),
                for (final line in cart.lines) CartItemTile(line: line),
                const SizedBox(height: AppSpacing.s8),
                Text('Способ получения', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                const OrderTypeToggle(),
                const SizedBox(height: AppSpacing.s16),
                if (orderType == OrderType.delivery) ...[
                  const DeliveryAddressForm(),
                  const SizedBox(height: AppSpacing.s12),
                ],
                Text('Время получения', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                const DeliveryTimeSelector(),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  key: const ValueKey('comment-field'),
                  onChanged: context.read<CheckoutCubit>().commentChanged,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий к заказу',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                const _OfferCheckbox(),
                const SizedBox(height: AppSpacing.s16),
                BonusSpendSection(cartTotal: cart.total),
                Text('Способ оплаты', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                const PaymentMethodSelector(),
                const SizedBox(height: AppSpacing.s16),
              ],
            ),
          ),
          _CheckoutBar(
            total: cart.total,
            deliveryFee: cart.deliveryFee,
            appliedBonusPoints: appliedBonusPoints,
            canSubmit: canSubmit,
            submitting: submitting,
          ),
        ],
      ),
    );
  }
}

class _OfferCheckbox extends StatefulWidget {
  const _OfferCheckbox();

  @override
  State<_OfferCheckbox> createState() => _OfferCheckboxState();
}

class _OfferCheckboxState extends State<_OfferCheckbox> {
  late final TapGestureRecognizer _offerRecognizer = TapGestureRecognizer()
    ..onTap = _showOffer;

  @override
  void dispose() {
    _offerRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accepted = context.select<CheckoutCubit, bool>(
      (cubit) => cubit.state.offerAccepted,
    );
    return InkWell(
      onTap: () => context.read<CheckoutCubit>().offerToggled(!accepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: const ValueKey('offer-checkbox'),
            value: accepted,
            onChanged: (value) =>
                context.read<CheckoutCubit>().offerToggled(value ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s12),
              child: Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  children: [
                    const TextSpan(text: 'Согласен с условиями '),
                    TextSpan(
                      text: 'Публичной оферты',
                      style: const TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _offerRecognizer,
                    ),
                    const TextSpan(text: ' и обработкой персональных данных'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOffer() => showLegalDocumentSheet(context, LegalDocument.offer);
}

/// Юридическая сноска под способами оплаты, перед кнопкой подтверждения:
/// «Оферты» и «Политикой конфиденциальности» открывают модальные окна
/// с полными текстами документов.
class _LegalFootnote extends StatefulWidget {
  const _LegalFootnote();

  @override
  State<_LegalFootnote> createState() => _LegalFootnoteState();
}

class _LegalFootnoteState extends State<_LegalFootnote> {
  late final TapGestureRecognizer _offerRecognizer = TapGestureRecognizer()
    ..onTap = () => showLegalDocumentSheet(context, LegalDocument.offer);
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => showLegalDocumentSheet(context, LegalDocument.privacy);

  @override
  void dispose() {
    _offerRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      key: const ValueKey('checkout-legal-footnote'),
      textAlign: TextAlign.center,
      TextSpan(
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.gray600),
        children: [
          const TextSpan(
            text: 'Нажимая кнопку оплаты, вы соглашаетесь с условиями ',
          ),
          TextSpan(
            text: 'Оферты',
            style: linkStyle,
            recognizer: _offerRecognizer,
          ),
          const TextSpan(text: ' и '),
          TextSpan(
            text: 'Политикой конфиденциальности',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          // Финальная точка вне ссылки: спан-recognizer в самом конце
          // текста на последней строке не получает hit-test (EOF-позиция
          // getClosestGlyphForOffset), поэтому ссылка не должна быть
          // последним символом абзаца.
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.deliveryFee,
    required this.appliedBonusPoints,
    required this.canSubmit,
    required this.submitting,
  });

  final Money total;

  /// Стоимость доставки из [CartState]; ноль — «Бесплатно».
  final Money deliveryFee;

  /// Бонусы к списанию (ADR-1614): 1 балл = 1 ₽, уже усечено до
  /// `min(баланс, floor(30% от чека))`; 0 — списание выключено.
  final int appliedBonusPoints;
  final bool canSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bonusDiscount = Money.kopecks(appliedBonusPoints * 100);
    final payable = total + deliveryFee - bonusDiscount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Сумма заказа', style: theme.textTheme.bodyMedium),
              Text(total.format(), style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            key: const ValueKey('delivery-fee-row'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Доставка', style: theme.textTheme.bodyMedium),
              Text(
                deliveryFee.isZero ? 'Бесплатно' : deliveryFee.format(),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          if (appliedBonusPoints > 0) ...[
            Row(
              key: const ValueKey('bonus-discount-row'),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Оплата бонусами',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  '−${bonusDiscount.format()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Итого', style: theme.textTheme.titleMedium),
              Text(payable.format(), style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          const _LegalFootnote(),
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('checkout-submit-button'),
              onPressed: canSubmit ? () => _submit(context) : null,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text('Оформить заказ на ${payable.format()}'),
            ),
          ),
        ],
      ),
    );
  }

  /// Auth gate: an anonymous guest signs in via the SMS sheet first; the
  /// cart (CustomerCartBloc) is untouched, so after the sheet closes the
  /// submit proceeds with the Bearer token bound to the order.
  Future<void> _submit(BuildContext context) async {
    if (!context.read<AuthBloc>().state.isAuthenticated) {
      final authenticated = await showAuthFlowSheet(context);
      if (!authenticated || !context.mounted) return;
    }
    if (!context.mounted) return;
    final checkout = context.read<CheckoutCubit>();
    final cart = context.read<CustomerCartBloc>().state;
    // «Списать бонусы»: пересчитываем лимит на момент отправки — сервер
    // всё равно повторит проверку 30% и баланса (ADR-1614).
    final bonusPoints = checkout.state.bonusSpendEnabled
        ? context.read<LoyaltyCubit>().state.maxSpendablePoints(cart.total)
        : 0;
    checkout.submit(
      orderType: context.read<OrderTypeCubit>().state,
      lines: cart.lines,
      bonusPoints: bonusPoints,
    );
  }
}
