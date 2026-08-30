import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// UI-803 Data Display — Halal certification badge.
///
/// Renders only when the item holds a valid HALAL certification tag
/// (`isHalal == true` in the Menu & Product API contract).
class HalalStatusBadge extends StatelessWidget {
  const HalalStatusBadge({super.key, required this.isHalal, this.compact = false});

  final bool isHalal;

  /// Compact variant shows the icon only (used on dense product cards).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!isHalal) return const SizedBox.shrink();

    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.statusHalal,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Semantics(
      label: 'Халяль',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.s4 : AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.statusHalalContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.statusHalal),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 14,
              color: AppColors.statusHalal,
            ),
            if (!compact) ...[
              const SizedBox(width: AppSpacing.s4),
              Text('HALAL', style: textStyle),
            ],
          ],
        ),
      ),
    );
  }
}
