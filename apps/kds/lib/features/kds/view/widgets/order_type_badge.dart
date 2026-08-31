import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/kds_order_models.dart';

/// UI-804 — fulfilment type chip: Зал / С собой / Доставка.
class OrderTypeBadge extends StatelessWidget {
  const OrderTypeBadge({super.key, required this.type, this.tableNumber});

  final KdsOrderType type;

  /// Shown next to the label for dine-in orders.
  final String? tableNumber;

  @override
  Widget build(BuildContext context) {
    final (icon, label, background, foreground) = switch (type) {
      KdsOrderType.dineIn => (
        Icons.restaurant_outlined,
        tableNumber != null ? 'Зал · стол $tableNumber' : 'Зал',
        AppColors.infoContainer,
        AppColors.onInfoContainer,
      ),
      KdsOrderType.takeaway => (
        Icons.shopping_bag_outlined,
        'С собой',
        AppColors.secondaryContainer,
        AppColors.onSecondaryContainer,
      ),
      KdsOrderType.delivery => (
        Icons.delivery_dining_outlined,
        'Доставка',
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.s4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
