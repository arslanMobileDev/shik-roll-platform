import 'package:dio/dio.dart';

import '../../../core/auth/auth_token_provider.dart';
import '../../../core/network/api_client.dart';
import 'payment.dart';

/// Failure surfaced by the payments data layer.
final class PaymentsException implements Exception {
  const PaymentsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'PaymentsException($statusCode): $message';
}

/// Online acquiring for the guest app (Payments API, `POST /payments/create`).
abstract interface class CustomerPaymentsRepository {
  Future<Payment> createPayment(String orderId);
}

/// Remote implementation over the Payments API contract (API-702).
final class RemoteCustomerPaymentsRepository
    implements CustomerPaymentsRepository {
  RemoteCustomerPaymentsRepository(this._client, [this._tokenProvider]);

  final ApiClient _client;

  /// When a guest session is active, its Bearer token is sent along so the
  /// backend binds the payment to the authenticated customer.
  final AuthTokenProvider? _tokenProvider;

  @override
  Future<Payment> createPayment(String orderId) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/payments/create',
        data: {'orderId': orderId},
        options: Options(
          headers: {
            if (_tokenProvider?.authorizationHeader != null)
              'Authorization': _tokenProvider!.authorizationHeader,
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        throw PaymentsException(
          'Пустой ответ сервера при создании платежа. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return Payment.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const PaymentsException(
        'Некорректный ответ сервера. Попробуйте ещё раз.',
      );
    }
  }

  /// Translates transport failures into a message the guest can act on.
  static PaymentsException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => PaymentsException(
        'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        statusCode: statusCode,
      ),
      DioExceptionType.connectionError => PaymentsException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when (statusCode ?? 0) >= 500 =>
        PaymentsException(
          'Сервер временно недоступен. Попробуйте оплатить позже.',
          statusCode: statusCode,
        ),
      DioExceptionType.badResponse => PaymentsException(
        _backendMessage(error.response) ??
            'Не удалось создать платёж. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.cancel => PaymentsException(
        'Создание платежа отменено.',
        statusCode: statusCode,
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => PaymentsException(
        'Ошибка сети при создании платежа. Попробуйте ещё раз.',
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
