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
          'Пустой ответ сервера при оформлении заказа. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return GuestOrder.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const OrdersException(
        'Некорректный ответ сервера. Попробуйте ещё раз.',
      );
    }
  }

  /// Translates transport failures into a message the guest can act on.
  static OrdersException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => OrdersException(
        'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        statusCode: statusCode,
      ),
      DioExceptionType.connectionError => OrdersException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when (statusCode ?? 0) >= 500 =>
        OrdersException(
          'Сервер временно недоступен. Попробуйте оформить заказ позже.',
          statusCode: statusCode,
        ),
      DioExceptionType.badResponse => OrdersException(
        _backendMessage(error.response) ??
            'Не удалось оформить заказ. Проверьте данные и попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.cancel => OrdersException(
        'Отправка заказа отменена.',
        statusCode: statusCode,
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => OrdersException(
        'Ошибка сети при оформлении заказа. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
    };
  }

  /// NestJS error payloads: `{ message: '…' }` or `{ message: […] }`.
  static String? _backendMessage(Response<dynamic>? response) {
    final data = response?.data;
    if (data is! Map<String, dynamic>) return null;
    return switch (data['message']) {
      String message when message.isNotEmpty => message,
      List<dynamic> messages when messages.isNotEmpty =>
        messages.first.toString(),
      _ => null,
    };
  }
}
