import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// SHIK ROLL wordmark: white "SHIK" + terracotta "ROLL".
class ShikRollLogo extends StatelessWidget {
  const ShikRollLogo({super.key, this.fontSize = 20, this.onDark = true});

  final double fontSize;

  /// Renders "SHIK" in white (sidebar) or ink (top bar on light bg).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'SHIK',
            style: TextStyle(
              color: onDark ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 1.2,
            ),
          ),
          TextSpan(
            text: ' ROLL',
            style: TextStyle(
              color: AppColors.terracotta,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
