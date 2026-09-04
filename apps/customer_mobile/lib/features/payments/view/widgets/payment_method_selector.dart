import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../cart/bloc/checkout_cubit.dart';
import '../../data/payment_method.dart';

/// Карточки выбора способа оплаты на чекауте (API-702).
///
/// Выбор хранится в [CheckoutCubit]; виджет только рендерит состояние и
/// пробрасывает тапы.
class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.select<CheckoutCubit, PaymentMethod>(
      (cubit) => cubit.state.paymentMethod,
    );
    return Column(
      children: [
        for (final method in PaymentMethod.values) ...[
          _PaymentMethodCard(method: method, selected: method == selected),
          if (method != PaymentMethod.values.last)
            const SizedBox(height: AppSpacing.s8),
        ],
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({required this.method, required this.selected});

  final PaymentMethod method;
  final bool selected;

  IconData get _icon => switch (method) {
    PaymentMethod.yookassa => Icons.account_balance_wallet_outlined,
    PaymentMethod.cash => Icons.payments_outlined,
    PaymentMethod.terminal => Icons.credit_card_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('payment-method-${method.name}'),
      borderRadius: BorderRadius.circular(AppRadius.r12),
      onTap: () => context.read<CheckoutCubit>().paymentMethodSelected(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.gray300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              color: selected ? AppColors.primary : AppColors.gray600,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                method.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              key: ValueKey('payment-method-check-${method.name}'),
              color: selected ? AppColors.primary : AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }
}
