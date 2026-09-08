import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/halal_status_badge.dart';
import '../../data/kds_order_models.dart';
import 'order_delay_timer.dart';
import 'order_type_badge.dart';

/// One-tap cook action available for an order in its current column.
typedef KdsOrderAction = void Function(KdsOrderStatus nextStatus);

/// UI-804 / ADR-1618 — kitchen order card.
///
/// Large order number, fulfilment type, color-coded delay timer, items with
/// modifiers, 100% Halal badge, customer comment and a single primary action
/// («Начать готовить» / «Готово») matching the order's column. READY cards
/// have no kitchen action — handout (READY → COMPLETED) belongs to POS and
/// courier flows, never to the kitchen board.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onAction,
    this.isFresh = false,
    this.isPending = false,
    this.clockOffset = Duration.zero,
    this.now,
  });

  final KdsOrder order;

  /// Dispatched with the next status when the cook taps the action button.
  final KdsOrderAction onAction;

  /// Newly arrived — rendered with a highlight border.
  final bool isFresh;

  /// Status transition in flight — button disabled with a spinner.
  final bool isPending;

  /// Server-clock correction, forwarded to [OrderDelayTimer].
  final Duration clockOffset;

  /// Fixed clock for tests, forwarded to [OrderDelayTimer].
  final DateTime? now;

  /// Next kitchen-owned transition for the order's current column.
  static ({KdsOrderStatus status, String label, IconData icon})? nextActionFor(
    KdsOrderStatus status,
  ) => switch (status) {
    KdsOrderStatus.confirmed => (
      status: KdsOrderStatus.cooking,
      label: 'Начать готовить',
      icon: Icons.soup_kitchen_outlined,
    ),
    KdsOrderStatus.cooking => (
      status: KdsOrderStatus.ready,
      label: 'Готово',
      icon: Icons.check_circle_outline,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final action = nextActionFor(order.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isFresh ? AppColors.primary : AppColors.gray300,
          width: isFresh ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray900.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrderHeader(order: order, clockOffset: clockOffset, now: now),
                const SizedBox(height: AppSpacing.s8),
                const Divider(),
                for (final item in order.items) _OrderItemTile(item: item),
                if (order.comment?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.s8),
                  _OrderComment(comment: order.comment!),
                ],
              ],
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s12,
                0,
                AppSpacing.s12,
                AppSpacing.s12,
              ),
              child: FilledButton.icon(
                key: Key('order-action-${order.id}'),
                onPressed: isPending ? null : () => onAction(action.status),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: textTheme.labelLarge,
                ),
                icon: isPending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(action.icon),
                label: Text(action.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.order,
    this.clockOffset = Duration.zero,
    this.now,
  });

  final KdsOrder order;
  final Duration clockOffset;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '#${order.orderNumber}',
                style: AppTypography.orderNumber.copyWith(
                  color: AppColors.gray900,
                ),
              ),
            ),
            OrderDelayTimer(
              since: order.statusSince,
              clockOffset: clockOffset,
              now: now,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            OrderTypeBadge(type: order.type, tableNumber: order.tableNumber),
            const HalalStatusBadge(),
          ],
        ),
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final KdsOrderItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.quantity}×',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  item.name,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (item.modifiers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.s32,
                top: AppSpacing.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in item.modifiers)
                    Text(
                      '• ${m.name}${m.quantity > 1 ? ' ×${m.quantity}' : ''}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.gray700,
                      ),
                    ),
                ],
              ),
            ),
          if (item.comment?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.s32,
                top: AppSpacing.s4,
              ),
              child: Text(
                item.comment!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderComment extends StatelessWidget {
  const _OrderComment({required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 16,
            color: AppColors.onWarningContainer,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              comment,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
