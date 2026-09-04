import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/guest_order.dart';

/// Congratulations screen after a successful checkout: order number and a
/// countdown of the estimated waiting time.
class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.order,
    required this.onBackToMenu,
    this.paidOnline = false,
  });

  final GuestOrder order;

  /// Switches the shell back to the menu tab (after this route pops).
  final VoidCallback onBackToMenu;

  /// Заказ уже оплачен через ЮKassa — показываем бейдж «Оплачено онлайн».
  final bool paidOnline;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  /// Demo estimate until the backend exposes per-order ETAs.
  static const _initialSeconds = 30 * 60;

  Timer? _timer;
  int _secondsLeft = _initialSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsLeft == 0) return;
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_outline,
                size: 72,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Заказ #${widget.order.orderNumber} принят!',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Готовим для вас',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.gray700,
                ),
              ),
              if (widget.paidOnline) ...[
                const SizedBox(height: AppSpacing.s12),
                Container(
                  key: const ValueKey('paid-online-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        'Оплачено онлайн (ЮKassa)',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              Text(
                'Примерное время ожидания',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.gray600,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                _countdown,
                key: const ValueKey('wait-countdown'),
                style: theme.textTheme.displaySmall,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('back-to-menu-button'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onBackToMenu();
                  },
                  child: const Text('Вернуться в меню'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
