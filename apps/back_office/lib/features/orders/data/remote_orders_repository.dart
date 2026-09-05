import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/order.dart';
import 'models/order_payment.dart';
import 'orders_repository.dart';

/// HTTP implementation of [OrdersRepository] against the live
/// orders/payments API (openapi: GET /orders, GET /payments/order/{id}).
final class RemoteOrdersRepository implements OrdersRepository {
  RemoteOrdersRepository({ApiClient? client})
    : _dio = (client ?? ApiClient()).dio;

  final Dio _dio;

  @override
  Future<OrdersPage> fetchOrders({
    required String branchId,
    OrderStatus? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/orders',
        queryParameters: {
          'branchId': branchId,
          if (status != null) 'status': status.wireName,
          'page': page,
          'limit': limit,
        },
      );
      return OrdersPage.fromJson(response.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw OrdersApiException(_describe(e));
    }
  }

  @override
  Future<OrderPayment?> fetchOrderPayment({required String orderId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/order/$orderId',
      );
      final payment = response.data?['payment'];
      if (payment is! Map<String, dynamic>) return null;
      return OrderPayment.fromJson(payment);
    } on DioException catch (e) {
      throw OrdersApiException(_describe(e));
    }
  }

  String _describe(DioException e) =>
      'API ${e.response?.statusCode ?? 'error'}: ${e.message ?? 'network failure'}';
}
