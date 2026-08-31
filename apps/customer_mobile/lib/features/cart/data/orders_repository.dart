import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'create_order_request.dart';
import 'guest_order.dart';

/// Failure surfaced by the orders data layer.
final class OrdersException implements Exception {
  const OrdersException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'OrdersException($statusCode): $message';
}

/// Checkout access for the guest app (Orders API, `POST /orders`).
abstract interface class CustomerOrdersRepository {
  Future<GuestOrder> createOrder(CreateOrderRequest request);
}

/// Remote implementation over the Orders API contract.
final class RemoteCustomerOrdersRepository implements CustomerOrdersRepository {
  RemoteCustomerOrdersRepository(this._client);

  final ApiClient _client;

  @override
  Future<GuestOrder> createOrder(CreateOrderRequest request) async {
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
      return GuestOrder.fromJson(data);
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
