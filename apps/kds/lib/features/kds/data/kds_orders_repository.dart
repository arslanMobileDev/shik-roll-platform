import '../../../core/network/api_client.dart';
import 'kds_order_models.dart';

/// Source of kitchen orders (API-702 `OrdersController`).
///
/// The board fetches one page of branch orders without a `status` filter and
/// buckets them client-side — the API accepts a single status per request,
/// while the board shows NEW+CONFIRMED, COOKING and READY at once.
abstract interface class KdsOrdersRepository {
  /// `GET /orders?branchId=…&page=…&limit=…`
  Future<List<KdsOrder>> fetchOrders({
    required String branchId,
    int page = 1,
    int limit = 50,
  });

  /// `PATCH /orders/{id}/status` — state-machine-validated transition.
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
  });
}

/// Remote implementation against the live Orders API.
final class RemoteKdsOrdersRepository implements KdsOrdersRepository {
  RemoteKdsOrdersRepository(ApiClient client) : _client = client;

  final ApiClient _client;

  @override
  Future<List<KdsOrder>> fetchOrders({
    required String branchId,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/orders',
      queryParameters: {'branchId': branchId, 'page': page, 'limit': limit},
    );
    final data = (response.data?['data'] as List?) ?? const [];
    return [for (final o in data) KdsOrder.fromJson(o as Map<String, dynamic>)];
  }

  @override
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
  }) async {
    final response = await _client.dio.patch<Map<String, dynamic>>(
      '/orders/$orderId/status',
      data: {'status': status.wireName},
    );
    final body = response.data;
    if (body == null) {
      throw StateError('Empty response for order $orderId status update');
    }
    return KdsOrder.fromJson(body);
  }
}
