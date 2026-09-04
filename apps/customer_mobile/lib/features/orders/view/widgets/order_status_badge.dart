import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Colored pill with the guest-facing order status label.
///
/// Backend statuses map to the guest vocabulary: NEW/CONFIRMED/COOKING →
/// «Готовится», READY → «В пути» (доставка) / «Готов к выдаче»,
/// COMPLETED → «Доставлен» / «Завершён», CANCELLED → «Отменён».
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status, required this.type});

  /// Backend status (`NEW`, `CONFIRMED`, `COOKING`, `READY`, …).
  final String status;

  /// `DELIVERY` / `TAKEAWAY` / `DINE_IN`.
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      'NEW' || 'CONFIRMED' || 'COOKING' => (
        'Готовится',
        AppColors.warningContainer,
        AppColors.warning,
      ),
      'READY' => (
        type == 'DELIVERY' ? 'В пути' : 'Готов к выдаче',
        AppColors.secondaryContainer,
        AppColors.info,
      ),
      'COMPLETED' => (
        type == 'DELIVERY' ? 'Доставлен' : 'Завершён',
        AppColors.statusHalalContainer,
        AppColors.statusHalal,
      ),
      'CANCELLED' => ('Отменён', AppColors.gray200, AppColors.gray600),
      _ => (status, AppColors.gray200, AppColors.gray600),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
