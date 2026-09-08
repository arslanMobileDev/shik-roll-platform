import '../models/courier.dart';
import '../models/courier_order.dart';
import '../models/courier_order_event.dart';

/// Thrown when the PIN/phone pair is rejected by the backend.
class CourierAuthException implements Exception {
  const CourierAuthException([this.message = 'Неверный PIN или телефон']);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when an order mutation conflicts with the server state
/// (claim race, invalid transition, second active order — HTTP 409).
class CourierOrderConflictException implements Exception {
  const CourierOrderConflictException([
    this.message = 'Статус заказа изменился. Обновите список',
  ]);
  final String message;

  @override
  String toString() => message;
}

/// Courier app data contract (ADR-1617). Implementations:
/// [FakeCourierRepository] (offline demo) and [RemoteCourierRepository]
/// (Dio over the guarded backend contract).
///
/// Identity never travels in requests: the backend reads courier/branch from
/// the verified JWT attached by CourierAuthInterceptor.
abstract interface class CourierRepository {
  /// POST /couriers/auth/pin — {pin, phone} -> {token, courier}.
  Future<({String token, Courier courier})> loginWithPin({
    required String pin,
    required String phone,
  });

  /// GET /couriers/orders/active — branch-scoped COOKING + READY + ON_WAY
  /// delivery feed (unassigned + own).
  Future<List<CourierOrder>> fetchActiveOrders();

  /// PATCH /couriers/orders/{id}/status {READY} — atomic claim of an
  /// unassigned READY order.
  Future<void> claimOrder(String orderId);

  /// PATCH /couriers/orders/{id}/status {ON_WAY} — start own delivery.
  Future<void> startDelivery(String orderId);

  /// PATCH /couriers/orders/{id}/status {COMPLETED} — finish own delivery.
  Future<void> completeDelivery(String orderId);

  /// Authorized SSE stream of branch order events (GET /couriers/stream).
  /// The stream ends or errors on connection loss; reconnect with backoff
  /// is the caller's job.
  Stream<CourierOrderEvent> watchOrders();
}
