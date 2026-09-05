import 'package:dio/dio.dart';

import '../models/courier.dart';
import '../models/courier_order.dart';
import 'courier_repository.dart';

/// Remote repository over the fixed backend contract:
///
/// * POST /couriers/auth/pin {pin, phone} -> {token, courier:{id,name}}
/// * GET  /couriers/orders/active?branchId=... -> [order, ...]
/// * PATCH /orders/{id}/status {status, courierId}
class RemoteCourierRepository implements CourierRepository {
  RemoteCourierRepository({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  /// Bearer token of the current session (set after login).
  set token(String? value) {
    if (value == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $value';
    }
  }

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
      final courier = Courier.fromJson(courierJson);
      this.token = token;
      return (token: token, courier: courier);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw const CourierAuthException();
      }
      throw CourierAuthException('Сервер недоступен: ${e.message ?? e}');
    }
  }

  @override
  Future<List<CourierOrder>> fetchActiveOrders({
    required String branchId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/couriers/orders/active',
      queryParameters: {'branchId': branchId},
    );
    final raw = response.data ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CourierOrder.fromJson)
        .where(
          (o) =>
              o.status == OrderStatus.ready ||
              o.status == OrderStatus.delivering,
        )
        .toList();
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    required String courierId,
  }) {
    return _dio.patch<void>(
      '/orders/$orderId/status',
      data: {'status': status.wireName, 'courierId': courierId},
    );
  }
}
