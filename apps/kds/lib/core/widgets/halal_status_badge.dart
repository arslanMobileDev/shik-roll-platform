import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// UI-803 Data Display — Halal certification badge.
///
/// SHIK ROLL is a 100% Halal kitchen, so the badge is rendered for every
/// order card by default (`isHalal` stays as an explicit opt-out flag).
class HalalStatusBadge extends StatelessWidget {
  const HalalStatusBadge({
    super.key,
    this.isHalal = true,
    this.compact = false,
  });

  final bool isHalal;

  /// Compact variant shows the icon only (used on dense cards).
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
      label: '100% Халяль',
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
              Text('100% HALAL', style: textStyle),
            ],
          ],
        ),
      ),
    );
  }
}
