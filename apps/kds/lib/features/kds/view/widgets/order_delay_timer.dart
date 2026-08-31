import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Delay band of an order by age.
enum DelayBand {
  /// Younger than 10 minutes.
  onTime,

  /// 10–20 minutes.
  warning,

  /// Older than 20 minutes.
  late,
}

/// UI-804 — color-coded order age chip.
///
/// Green under 10 min, yellow 10–20 min, red over 20 min. Ticks every 30 s
/// while live; pass a fixed [now] in tests for deterministic rendering.
class OrderDelayTimer extends StatefulWidget {
  const OrderDelayTimer({super.key, required this.createdAt, this.now});

  final DateTime createdAt;

  /// Fixed clock for tests; when null the widget ticks by itself.
  final DateTime? now;

  /// Thresholds in minutes: [0, warningAfter) → green,
  /// [warningAfter, lateAfter] → yellow, beyond → red.
  static const int warningAfterMinutes = 10;
  static const int lateAfterMinutes = 20;

  static DelayBand bandFor(Duration age) {
    if (age.inMinutes < warningAfterMinutes) return DelayBand.onTime;
    if (age.inMinutes <= lateAfterMinutes) return DelayBand.warning;
    return DelayBand.late;
  }

  static String formatAge(Duration age) {
    if (age.isNegative) return '0 мин';
    final hours = age.inHours;
    final minutes = age.inMinutes.remainder(60);
    if (hours > 0) return '$hours ч $minutes мин';
    return '${age.inMinutes} мин';
  }

  @override
  State<OrderDelayTimer> createState() => _OrderDelayTimerState();
}

class _OrderDelayTimerState extends State<OrderDelayTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final age = now.difference(widget.createdAt);
    final band = OrderDelayTimer.bandFor(age);

    final (foreground, background) = switch (band) {
      DelayBand.onTime => (
        AppColors.timerOnTime,
        AppColors.timerOnTimeContainer,
      ),
      DelayBand.warning => (
        AppColors.timerWarning,
        AppColors.timerWarningContainer,
      ),
      DelayBand.late => (AppColors.timerLate, AppColors.timerLateContainer),
    };

    return Semantics(
      label: 'Время ожидания: ${OrderDelayTimer.formatAge(age)}',
      excludeSemantics: true,
      child: Container(
        key: const Key('order-delay-timer'),
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
            Icon(Icons.schedule, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.s4),
            Text(
              OrderDelayTimer.formatAge(age),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
