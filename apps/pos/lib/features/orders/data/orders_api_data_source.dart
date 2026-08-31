import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/order_entity.dart';
import 'create_order_request.dart';
import 'orders_repository.dart';

/// Transport for the Orders API (`POST /orders`).
///
/// Thin wrapper over the shared [ApiClient]; error mapping to
/// [OrdersException] happens here so callers stay transport-agnostic.
final class OrdersApiDataSource {
  OrdersApiDataSource(this._client);

  final ApiClient _client;

  Future<OrderEntity> createOrder(CreateOrderRequest request) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/orders',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw OrdersException(
          'Empty response from /orders',
          statusCode: response.statusCode,
        );
      }
      return OrderEntity.fromJson(data);
    } on DioException catch (e) {
      throw OrdersException(
        e.message ?? 'Network error while creating the order',
        statusCode: e.response?.statusCode,
      );
    } on FormatException catch (e) {
      throw OrdersException(e.message);
    }
  }
}
