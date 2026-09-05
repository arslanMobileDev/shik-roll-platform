import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Green pill badge — "100% Halal" brand compliance marker.
class HalalBadge extends StatelessWidget {
  const HalalBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.halalGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.halalGreen.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 14,
            color: AppColors.halalGreen,
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            const Text(
              '100% Halal',
              style: TextStyle(
                color: AppColors.halalGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
