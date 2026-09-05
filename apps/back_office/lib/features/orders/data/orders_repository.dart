import 'models/order.dart';
import 'models/order_payment.dart';

/// Orders journal data source (openapi /orders + /payments contract).
abstract interface class OrdersRepository {
  /// GET /orders?branchId={id}&status={wire}&page={page}&limit={limit}
  Future<OrdersPage> fetchOrders({
    required String branchId,
    OrderStatus? status,
    int page = 1,
    int limit = 50,
  });

  /// GET /payments/order/{orderId} — `null` when no payment is registered.
  Future<OrderPayment?> fetchOrderPayment({required String orderId});
}

/// Domain-level failure surfaced by the orders data source.
final class OrdersApiException implements Exception {
  const OrdersApiException(this.message);

  final String message;

  @override
  String toString() => 'OrdersApiException: $message';
}
