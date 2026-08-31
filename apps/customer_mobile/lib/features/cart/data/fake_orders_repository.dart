import '../../../core/utils/money.dart';
import 'create_order_request.dart';
import 'guest_order.dart';
import 'orders_repository.dart';

/// In-memory checkout for development and widget tests.
///
/// Used when `API_BASE_URL` is not configured: accepts every order and
/// returns the fixed demo order `#1042` in status `NEW`.
final class FakeCustomerOrdersRepository implements CustomerOrdersRepository {
  FakeCustomerOrdersRepository({
    this.latency = const Duration(milliseconds: 600),
  });

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  static const _demoOrderNumber = '1042';

  @override
  Future<GuestOrder> createOrder(CreateOrderRequest request) async {
    // A zero latency stays on the microtask queue (no timer), which keeps
    // tests deterministic.
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return const GuestOrder(
      id: 'demo-order-$_demoOrderNumber',
      orderNumber: _demoOrderNumber,
      status: 'NEW',
      totalAmount: Money.zero,
    );
  }
}
