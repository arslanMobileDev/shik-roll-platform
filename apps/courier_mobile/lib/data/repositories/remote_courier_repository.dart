import 'package:dio/dio.dart';

import '../models/courier.dart';
import '../models/courier_order.dart';
import '../models/courier_order_event.dart';
import 'courier_events_client.dart';
import 'courier_repository.dart';

/// Remote repository over the guarded backend contract (ADR-1617):
///
/// * POST  /couriers/auth/pin {pin, phone} -> {token, courier:{id,name}}
/// * GET   /couriers/orders/active -> [order, ...]   (JWT-scoped)
/// * PATCH /couriers/orders/{id}/status {status}     (JWT identity)
/// * GET   /couriers/stream                        (SSE order events)
///
/// The Dio instance must be configured by the composition root with
/// CourierAuthInterceptor; this class never touches the token itself.
class RemoteCourierRepository implements CourierRepository {
  RemoteCourierRepository({required this._dio});

  final Dio _dio;

  late final CourierEventsClient _eventsClient = CourierEventsClient(_dio);

  @override
  Future<({String token, Courier courier})> loginWithPin({
    required String pin,
    required String phone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/couriers/auth/pin',
        data: {'pin': pin, 'phone': phone},
      );
      final data = response.data ?? const <String, dynamic>{};
      final token = data['token'] as String?;
      final courierJson = data['courier'];
      if (token == null || courierJson is! Map<String, dynamic>) {
        throw const CourierAuthException('Некорректный ответ сервера');
      }
      return (token: token, courier: Courier.fromJson(courierJson));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw const CourierAuthException();
      }
      throw CourierAuthException('Сервер недоступен: ${e.message ?? e}');
    }
  }

  @override
  Future<List<CourierOrder>> fetchActiveOrders() async {
    final response = await _dio.get<List<dynamic>>('/couriers/orders/active');
    final raw = response.data ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CourierOrder.fromJson)
        .where(
          (o) =>
              o.type == OrderType.delivery &&
              (o.status == OrderStatus.cooking ||
                  o.status == OrderStatus.ready ||
                  o.status == OrderStatus.onWay),
        )
        .toList();
  }

  @override
  Future<void> claimOrder(String orderId) =>
      _transition(orderId, OrderStatus.ready);

  @override
  Future<void> startDelivery(String orderId) =>
      _transition(orderId, OrderStatus.onWay);

  @override
  Future<void> completeDelivery(String orderId) =>
      _transition(orderId, OrderStatus.completed);

  Future<void> _transition(String orderId, OrderStatus status) async {
    try {
      await _dio.patch<void>(
        '/couriers/orders/$orderId/status',
        data: {'status': status.wireName},
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 409) {
        throw const CourierOrderConflictException();
      }
      rethrow;
    }
  }

  @override
  Stream<CourierOrderEvent> watchOrders() => _eventsClient.watch();
}
