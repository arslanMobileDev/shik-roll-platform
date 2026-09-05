import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Personal shift production counter shown next to the cook in the KDS
/// header: «Выполнено за смену: X шт.» plus the average hand-out time.
class ShiftProductionBadge extends StatelessWidget {
  const ShiftProductionBadge({
    super.key,
    required this.completedCount,
    this.avgPrepTime,
  });

  /// Orders handed out («Выдано») by the cook during the current shift.
  final int completedCount;

  /// Average time from order creation to hand-out; hidden when unknown.
  final Duration? avgPrepTime;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avg = avgPrepTime;
    final label = StringBuffer('Выполнено за смену: $completedCount шт.');
    if (avg != null) {
      label.write(' · ~${(avg.inSeconds / 60).round()} мин');
    }
    return Container(
      key: const Key('shift-production-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.successContainer,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.done_all,
            size: 16,
            color: AppColors.onSuccessContainer,
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            label.toString(),
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.onSuccessContainer,
            ),
          ),
        ],
      ),
    );
  }
}
