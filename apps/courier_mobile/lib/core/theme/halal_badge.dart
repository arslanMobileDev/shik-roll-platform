import 'package:flutter/material.dart';

import 'shik_colors.dart';

/// «100% Halal» brand badge.
class HalalBadge extends StatelessWidget {
  const HalalBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: ShikColors.halalGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ShikColors.halalGreenDark, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            color: Colors.white,
            size: compact ? 14 : 16,
          ),
          const SizedBox(width: 4),
          Text(
            '100% Halal',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
