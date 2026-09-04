import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'halal_status_badge.dart';

/// Фирменный логотип SHIK ROLL для шапки каталога: белое «SHIK» +
/// терракотово-оранжевое «ROLL» (brandAccent) и бейдж Halal.
///
/// Рассчитан на тёмный фон AppBar ([AppColors.gray900]).
class ShikRollLogo extends StatelessWidget {
  const ShikRollLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          key: const ValueKey('shik-roll-logo'),
          TextSpan(
            style: base?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
            children: const [
              TextSpan(
                text: 'SHIK ',
                style: TextStyle(color: AppColors.onPrimary),
              ),
              TextSpan(
                text: 'ROLL',
                style: TextStyle(color: AppColors.brandAccent),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        const HalalStatusBadge(isHalal: true),
      ],
    );
  }
}
