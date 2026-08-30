import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Availability visual state for a menu item in the branch context.
enum AvailabilityStatus {
  /// Sellable: published, branch-available and not stop-listed.
  available,

  /// Disabled for the branch via the availability flag.
  unavailable,

  /// On the branch stop list.
  stopListed,
}

/// UI-803 Data Display — availability / stop-list badge.
///
/// Renders nothing for [AvailabilityStatus.available]; the badge exists to
/// flag the two sell-blocking states to the cashier.
class AvailabilityStatusBadge extends StatelessWidget {
  const AvailabilityStatusBadge({
    super.key,
    required this.status,
    this.stopListReason,
  });

  final AvailabilityStatus status;

  /// Optional stop-list reason, exposed through a tooltip.
  final String? stopListReason;

  @override
  Widget build(BuildContext context) {
    if (status == AvailabilityStatus.available) return const SizedBox.shrink();

    final isStop = status == AvailabilityStatus.stopListed;
    final color = isStop ? AppColors.statusStopList : AppColors.gray600;
    final container =
        isStop ? AppColors.statusStopListContainer : AppColors.gray200;
    final label = isStop ? 'Стоп-лист' : 'Недоступно';

    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStop ? Icons.block : Icons.visibility_off_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppSpacing.s4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    final reason = stopListReason;
    final labeled = Semantics(
      label: label,
      excludeSemantics: true,
      child: badge,
    );
    if (isStop && reason != null && reason.isNotEmpty) {
      return Tooltip(message: reason, child: labeled);
    }
    return labeled;
  }
}
