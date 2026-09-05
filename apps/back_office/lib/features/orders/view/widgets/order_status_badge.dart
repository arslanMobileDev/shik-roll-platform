import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/order.dart';

/// Colored status badge for order rows and the details header.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  static Color colorOf(OrderStatus status) => switch (status) {
    OrderStatus.newOrder => AppColors.terracotta,
    OrderStatus.confirmed => AppColors.info,
    OrderStatus.cooking => AppColors.warning,
    OrderStatus.ready => AppColors.success,
    OrderStatus.completed => AppColors.inkMuted,
    OrderStatus.cancelled => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
