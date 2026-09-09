import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../cart/data/guest_order.dart';
import '../../loyalty/bloc/loyalty_cubit.dart';
import '../../orders/data/order_tracking_repository.dart';
import '../../orders/presentation/screens/order_tracking_screen.dart';
import '../data/payment.dart';

typedef PaymentUrlLauncher = Future<bool> Function(Uri url);

Future<bool> launchExternalPaymentUrl(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Opens the YooKassa redirect in the system browser. Once the URL has been
/// handed to the browser, the route underneath becomes live order tracking;
/// it is visible when the customer returns to the app.
class PaymentStatusScreen extends StatefulWidget {
  const PaymentStatusScreen({
    super.key,
    required this.order,
    required this.payment,
    required this.trackingRepository,
    required this.onBackToMenu,
    this.loyaltyCubit,
    this.urlLauncher = launchExternalPaymentUrl,
  });

  final GuestOrder order;
  final Payment payment;
  final OrderTrackingRepository trackingRepository;
  final LoyaltyCubit? loyaltyCubit;
  final VoidCallback onBackToMenu;
  final PaymentUrlLauncher urlLauncher;

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  bool _opening = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPayment());
  }

  Future<void> _openPayment() async {
    if (mounted) {
      setState(() {
        _opening = true;
        _error = null;
      });
    }
    final uri = Uri.tryParse(widget.payment.paymentUrl);
    var opened = false;
    try {
      opened = uri != null && await widget.urlLauncher(uri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (!opened) {
      setState(() {
        _opening = false;
        _error = 'Не удалось открыть страницу оплаты. Попробуйте ещё раз.';
      });
      return;
    }
    _openTracking();
  }

  void _openTracking() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OrderTrackingScreen(
          orderId: widget.order.id,
          orderNumber: widget.order.orderNumber,
          trackingRepository: widget.trackingRepository,
          totalPrice: widget.order.totalAmount.rubles,
          loyaltyCubit: widget.loyaltyCubit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата заказа')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.open_in_browser,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                _opening
                    ? 'Открываем страницу ЮKassa…'
                    : 'Не удалось открыть оплату',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (_opening) ...[
                const SizedBox(height: AppSpacing.s16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.s16),
                FilledButton(
                  key: const ValueKey('retry-payment-button'),
                  onPressed: _openPayment,
                  child: const Text('Повторить'),
                ),
                TextButton(
                  key: const ValueKey('continue-tracking-button'),
                  onPressed: _openTracking,
                  child: const Text('Перейти к статусу заказа'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
