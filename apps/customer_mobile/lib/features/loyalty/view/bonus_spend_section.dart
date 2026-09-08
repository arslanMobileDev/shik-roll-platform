import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../cart/bloc/checkout_cubit.dart';
import '../bloc/loyalty_cubit.dart';

/// Bonus spend toggle for the cart (ADR-1614): «Списать бонусы» capped at
/// 30% of the item amount and by the current balance. Only rendered for an
/// authenticated guest with a loaded, non-empty balance; the applied points
/// live in [CheckoutCubit] and the payable total is recomputed live.
class BonusSpendSection extends StatelessWidget {
  const BonusSpendSection({super.key, required this.cartTotal});

  /// Cart subtotal (the bonus base — promotion discounts are not applied
  /// in the app yet).
  final Money cartTotal;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthBloc, bool>(
      (bloc) => bloc.state.isAuthenticated,
    );
    final loyalty = context.watch<LoyaltyCubit>().state;
    if (!isAuthenticated || !loyalty.hasBalance || loyalty.balance <= 0) {
      return const SizedBox.shrink();
    }

    final applicable = loyalty.maxSpendablePoints(cartTotal);
    final enabled = context.select<CheckoutCubit, bool>(
      (cubit) => cubit.state.bonusSpendEnabled,
    );

    return Card(
      key: const ValueKey('bonus-spend-section'),
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: SwitchListTile(
        key: const ValueKey('bonus-spend-switch'),
        value: enabled && applicable > 0,
        onChanged: applicable > 0
            ? (value) => context.read<CheckoutCubit>().bonusSpendToggled(value)
            : null,
        secondary: const Icon(Icons.stars_rounded, color: AppColors.warning),
        title: const Text('Списать бонусы'),
        subtitle: Text(
          applicable > 0
              ? 'На балансе ${loyalty.balance} бонусов · спишется $applicable (до 30% от чека)'
              : 'На балансе ${loyalty.balance} бонусов · минимальный чек для списания не набран',
        ),
      ),
    );
  }
}
