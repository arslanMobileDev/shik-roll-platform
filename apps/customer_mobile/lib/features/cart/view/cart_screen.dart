import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/view/auth_flow.dart';
import '../../menu/bloc/order_type.dart';
import '../../menu/view/widgets/order_type_toggle.dart';
import '../../payments/view/payment_status_screen.dart';
import '../../payments/view/widgets/payment_method_selector.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';
import '../bloc/checkout_cubit.dart';
import '../bloc/customer_cart_bloc.dart';
import '../data/cart_line.dart';
import 'order_success_screen.dart';

/// Guest cart tab: positions with modifiers, delivery/pickup switch,
/// address & comment, offer consent and the checkout button.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.onGoToMenu});

  /// Switches the shell back to the menu tab.
  final VoidCallback onGoToMenu;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckoutCubit, CheckoutState>(
      listenWhen: (previous, next) => previous.status != next.status,
      listener: (context, state) {
        switch (state.status) {
          case CheckoutStatus.success:
            final order = state.placedOrder!;
            final payment = state.payment;
            context.read<CustomerCartBloc>().add(const CartCleared());
            context.read<CheckoutCubit>().reset();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => payment != null && !payment.isSucceeded
                    // Онлайн-оплата ЮKassa: сначала эмуляция страницы оплаты.
                    ? PaymentStatusScreen(
                        order: order,
                        payment: payment,
                        onBackToMenu: onGoToMenu,
                      )
                    : OrderSuccessScreen(
                        order: order,
                        onBackToMenu: onGoToMenu,
                        paidOnline: payment?.isSucceeded ?? false,
                      ),
              ),
            );
          case CheckoutStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage ?? 'Не удалось оформить заказ',
                ),
              ),
            );
          case CheckoutStatus.editing || CheckoutStatus.submitting:
            break;
        }
      },
      child: BlocBuilder<CustomerCartBloc, CartState>(
        builder: (context, cart) {
          if (cart.isEmpty) return _EmptyCart(onGoToMenu: onGoToMenu);
          return _CartContent(cart: cart);
        },
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onGoToMenu});

  final VoidCallback onGoToMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text('Корзина пуста', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Добавьте блюда из меню',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton.tonal(
              key: const ValueKey('go-to-menu-button'),
              onPressed: onGoToMenu,
              child: const Text('Перейти к меню'),
            ),
          ],
        ),
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
    final submitting = checkout.status == CheckoutStatus.submitting;
    final canSubmit = checkout.canSubmit(
      orderType: orderType,
      cartIsEmpty: cart.isEmpty,
    );

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
                for (final line in cart.lines) _CartLineTile(line: line),
                const SizedBox(height: AppSpacing.s8),
                Text('Способ получения', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                const OrderTypeToggle(),
                const SizedBox(height: AppSpacing.s16),
                TextField(
                  key: const ValueKey('address-field'),
                  enabled: orderType == OrderType.delivery,
                  onChanged: context.read<CheckoutCubit>().addressChanged,
                  decoration: const InputDecoration(
                    labelText: 'Адрес доставки',
                    hintText: 'Улица, дом, квартира',
                    border: OutlineInputBorder(),
                  ),
                ),
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
                Text('Способ оплаты', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                const PaymentMethodSelector(),
                const SizedBox(height: AppSpacing.s16),
              ],
            ),
          ),
          _CheckoutBar(
            total: cart.total,
            canSubmit: canSubmit,
            submitting: submitting,
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartBloc = context.read<CustomerCartBloc>();
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.item.name, style: theme.textTheme.titleSmall),
                      if (line.modifiers.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          line.modifiersLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        '${line.unitPrice.format()} / шт',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(line.total.format(), style: theme.textTheme.titleSmall),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: ValueKey('qty-minus-${line.id}'),
                  onPressed: () => cartBloc.add(
                    CartLineQuantityChanged(lineId: line.id, delta: -1),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Убавить',
                ),
                Text('${line.quantity}', style: theme.textTheme.titleSmall),
                IconButton(
                  key: ValueKey('qty-plus-${line.id}'),
                  onPressed: () => cartBloc.add(
                    CartLineQuantityChanged(lineId: line.id, delta: 1),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Прибавить',
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey('remove-${line.id}'),
                  onPressed: () =>
                      cartBloc.add(CartLineRemoved(lineId: line.id)),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.gray600,
                  ),
                  tooltip: 'Удалить',
                ),
              ],
            ),
          ],
        ),
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

  void _showOffer() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Публичная оферта'),
        content: const SingleChildScrollView(
          child: Text(
            'Полный текст оферты публикуется на сайте SHIK ROLL. '
            'Оформляя заказ, вы принимаете условия продажи товаров и '
            'даёте согласие на обработку персональных данных.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.canSubmit,
    required this.submitting,
  });

  final Money total;
  final bool canSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text('Итого', style: theme.textTheme.titleMedium),
              Text(total.format(), style: theme.textTheme.titleMedium),
            ],
          ),
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
                  : Text('Оформить заказ на ${total.format()}'),
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
    context.read<CheckoutCubit>().submit(
      orderType: context.read<OrderTypeCubit>().state,
      lines: context.read<CustomerCartBloc>().state.lines,
    );
  }
}
