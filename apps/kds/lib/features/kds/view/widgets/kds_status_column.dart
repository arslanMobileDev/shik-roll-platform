import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../shift/bloc/cook_shift_cubit.dart';
import '../../bloc/kds_orders_bloc.dart';
import '../../bloc/kds_orders_event.dart';
import '../../data/kds_order_models.dart';
import 'order_card.dart';

/// UI-804 — one board column («В очереди» / «Готовятся» / «Готовы»).
class KdsStatusColumn extends StatelessWidget {
  const KdsStatusColumn({
    super.key,
    required this.title,
    required this.accent,
    required this.orders,
    this.freshOrderIds = const {},
    this.pendingOrderId,
    this.now,
  });

  final String title;
  final Color accent;
  final List<KdsOrder> orders;
  final Set<String> freshOrderIds;

  /// Order currently transitioning — its card shows the in-progress state.
  final String? pendingOrderId;

  /// Fixed clock for tests, forwarded to order cards.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(color: AppColors.gray300),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: Text(title, style: textTheme.titleMedium)),
              Text(
                '${orders.length}',
                style: textTheme.titleMedium?.copyWith(color: accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Text(
                    'Нет заказов',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.gray500,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s8),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      key: Key('order-card-${order.id}'),
                      order: order,
                      isFresh: freshOrderIds.contains(order.id),
                      isPending: pendingOrderId == order.id,
                      now: now,
                      onAction: (next) => _dispatchAction(context, order, next),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Attributes the transition to the station cook and, on «Выдано», bumps
  /// their personal shift counter before the board refetches.
  void _dispatchAction(
    BuildContext context,
    KdsOrder order,
    KdsOrderStatus next,
  ) {
    final shiftState = context.read<CookShiftCubit>().state;
    final cook = shiftState.currentCook;
    if (next == KdsOrderStatus.completed && cook != null) {
      final handedOutAt = now ?? DateTime.now();
      context.read<CookShiftCubit>().recordOrderCompleted(
        prepTime: handedOutAt.difference(order.createdAt),
      );
    }
    context.read<KdsOrdersBloc>().add(
      KdsOrderStatusChangeRequested(
        orderId: order.id,
        status: next,
        cookId: cook?.id,
        shiftId: shiftState.shiftId,
      ),
    );
  }
}
