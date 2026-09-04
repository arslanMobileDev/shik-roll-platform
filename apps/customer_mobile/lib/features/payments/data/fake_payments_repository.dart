import 'payment.dart';
import 'payments_repository.dart';

/// In-memory acquiring for development and widget tests.
///
/// Used when `API_BASE_URL` is not configured: accepts every order and
/// returns a demo payment in status `PENDING` with a mock confirmation URL.
final class FakeCustomerPaymentsRepository
    implements CustomerPaymentsRepository {
  FakeCustomerPaymentsRepository({
    this.latency = const Duration(milliseconds: 400),
  });

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  @override
  Future<Payment> createPayment(String orderId) async {
    // A zero latency stays on the microtask queue (no timer), which keeps
    // tests deterministic.
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return Payment(
      id: 'demo-payment-$orderId',
      paymentUrl:
          'https://yoomoney.ru/checkout/payments/v2/demo?orderId=$orderId',
      status: PaymentStatus.pending,
    );
  }
}
