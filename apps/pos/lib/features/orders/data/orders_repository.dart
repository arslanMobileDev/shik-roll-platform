import '../domain/order_entity.dart';
import 'create_order_request.dart';
import 'orders_api_data_source.dart';

/// Failure surfaced by the orders data layer.
final class OrdersException implements Exception {
  const OrdersException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'OrdersException($statusCode): $message';
}

/// Checkout access for the POS (Orders API, `POST /orders`).
abstract interface class OrdersRepository {
  Future<OrderEntity> createOrder(CreateOrderRequest request);
}

/// Remote implementation over the Orders API contract.
final class RemoteOrdersRepository implements OrdersRepository {
  RemoteOrdersRepository(OrdersApiDataSource dataSource)
    : _dataSource = dataSource;

  final OrdersApiDataSource _dataSource;

  @override
  Future<OrderEntity> createOrder(CreateOrderRequest request) =>
      _dataSource.createOrder(request);
}
