import '../models/courier.dart';
import '../models/courier_order.dart';

/// Thrown when the PIN/phone pair is rejected by the backend.
class CourierAuthException implements Exception {
  const CourierAuthException([this.message = 'Неверный PIN или телефон']);
  final String message;

  @override
  String toString() => message;
}

/// Courier app data contract. Implementations: [FakeCourierRepository]
/// (offline demo) and [RemoteCourierRepository] (Dio, fixed API contract).
abstract interface class CourierRepository {
  /// POST /couriers/auth/pin — {pin, phone} -> {token, courier}.
  Future<({String token, Courier courier})> loginWithPin({
    required String pin,
    required String phone,
  });

  /// GET /couriers/orders/active?branchId=... — READY + DELIVERING orders.
  Future<List<CourierOrder>> fetchActiveOrders({required String branchId});

  /// PATCH /orders/{id}/status — {status, courierId}.
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    required String courierId,
  });
}
