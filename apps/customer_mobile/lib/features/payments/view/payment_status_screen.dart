import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../cart/data/guest_order.dart';
import '../../cart/view/order_success_screen.dart';
import '../data/payment.dart';

/// Эмуляция страницы оплаты ЮKassa: показывает confirmation URL из
/// `POST /payments/create` и кнопку демо-оплаты. В проде здесь открывается
/// [Payment.paymentUrl] (WebView / url_launcher), а статус подтверждается
/// вебхуком эквайера.
class PaymentStatusScreen extends StatelessWidget {
  const PaymentStatusScreen({
    super.key,
    required this.order,
    required this.payment,
    required this.onBackToMenu,
  });

  final GuestOrder order;
  final Payment payment;

  /// Switches the shell back to the menu tab (after the flow pops).
  final VoidCallback onBackToMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата заказа')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.credit_card_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Счёт на оплату выставлен',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Заказ #${order.orderNumber} ждёт оплаты через ЮKassa',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.gray700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s24),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(color: AppColors.gray300),
                ),
                child: SelectableText(
                  payment.paymentUrl,
                  key: const ValueKey('payment-url'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.gray700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              FilledButton(
                key: const ValueKey('mock-pay-button'),
                onPressed: () => _finish(context, paidOnline: true),
                child: const Text('Оплатить (демо)'),
              ),
              const SizedBox(height: AppSpacing.s8),
              TextButton(
                key: const ValueKey('pay-later-button'),
                onPressed: () => _finish(context, paidOnline: false),
                child: const Text('Оплатить при получении'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Мок-завершение оплаты: демо-оплата ведёт на экран успеха с бейджем
  /// «Оплачено онлайн (ЮKassa)», откладка — на тот же экран без бейджа.
  void _finish(BuildContext context, {required bool paidOnline}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OrderSuccessScreen(
          order: order,
          onBackToMenu: onBackToMenu,
          paidOnline: paidOnline,
        ),
      ),
    );
  }
}
