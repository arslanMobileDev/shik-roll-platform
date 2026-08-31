import '../../../core/utils/money.dart';
import '../domain/order_entity.dart';
import 'create_order_request.dart';
import 'orders_repository.dart';

/// In-memory checkout for development and widget tests.
///
/// Used when `API_BASE_URL` is not configured: accepts every order and
/// returns the fixed demo order `#1005` in status `NEW`.
final class FakeOrdersRepository implements OrdersRepository {
  FakeOrdersRepository({this.latency = const Duration(milliseconds: 600)});

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  static const _demoOrderNumber = '1005';

  @override
  Future<OrderEntity> createOrder(CreateOrderRequest request) async {
    // A zero latency stays on the microtask queue (no timer), which keeps
    // tests deterministic.
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return const OrderEntity(
      id: 'demo-order-$_demoOrderNumber',
      orderNumber: _demoOrderNumber,
      status: 'NEW',
      totalAmount: Money.zero,
    );
  }
}
