import 'package:dio/dio.dart';

import '../../../core/auth/auth_token_provider.dart';
import '../../../core/network/api_client.dart';
import 'auth_models.dart';

/// Failure surfaced by the auth data layer.
final class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Backend error code when present (`OTP_INVALID`, `OTP_EXPIRED`, …).
  final String? code;

  /// 401 on an authorized call: the stored token is no longer valid.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'AuthException($statusCode, $code): $message';
}

/// Guest SMS/OTP authentication (Auth API: `/auth/otp/*`, `/auth/me`).
abstract interface class AuthRepository {
  /// Sends the 4-digit code to [phone] (E.164).
  Future<OtpChallenge> sendOtp({required String phone});

  /// Verifies the [code]; the backend auto-creates the customer on the
  /// first sign-in and issues the JWT pair.
  Future<AuthSession> verifyOtp({required String phone, required String code});

  /// Profile of the authenticated guest (`GET /auth/me`, Bearer required).
  Future<GuestCustomer> getProfile();
}

/// Remote implementation over the Auth API contract.
final class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._client, this._tokenProvider);

  final ApiClient _client;
  final AuthTokenProvider _tokenProvider;

  @override
  Future<OtpChallenge> sendOtp({required String phone}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/otp/send',
        data: {'phone': phone},
      );
      final data = response.data;
      if (data == null) {
        throw AuthException(
          'Пустой ответ сервера. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return OtpChallenge.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const AuthException('Некорректный ответ сервера.');
    }
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone': phone, 'code': code},
      );
      final data = response.data;
      if (data == null) {
        throw AuthException(
          'Пустой ответ сервера. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return AuthSession.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const AuthException('Некорректный ответ сервера.');
    }
  }

  @override
  Future<GuestCustomer> getProfile() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/auth/me',
        options: Options(
          headers: {
            if (_tokenProvider.authorizationHeader != null)
              'Authorization': _tokenProvider.authorizationHeader,
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        throw AuthException(
          'Пустой ответ сервера. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return GuestCustomer.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const AuthException('Некорректный ответ сервера.');
    }
  }

  /// Translates transport and API failures into guest-readable messages.
  static AuthException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final code = _backendCode(error.response);
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => AuthException(
        'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.connectionError => AuthException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.badResponse when statusCode == 401 => AuthException(
        switch (code) {
          'OTP_EXPIRED' =>
            'Код истёк. Запросите новый и введите его в течение 3 минут.',
          'OTP_INVALID' => 'Неверный код. Проверьте цифры из SMS.',
          _ => 'Сессия истекла. Войдите ещё раз.',
        },
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.badResponse when (statusCode ?? 0) >= 500 =>
        AuthException(
          'Сервис авторизации временно недоступен. Попробуйте позже.',
          statusCode: statusCode,
          code: code,
        ),
      DioExceptionType.badResponse => AuthException(
        _backendMessage(error.response) ??
            'Не удалось выполнить запрос. Попробуйте ещё раз.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.cancel => AuthException(
        'Запрос отменён.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => AuthException(
        'Ошибка сети. Попробуйте ещё раз.',
        statusCode: statusCode,
        code: code,
      ),
    };
  }

  /// NestJS error payloads carry the code in `code` or as `message`.
  static String? _backendCode(Response<dynamic>? response) {
    final data = response?.data;
    if (data is! Map<String, dynamic>) return null;
    if (data['code'] case final String code when code.isNotEmpty) return code;
    return switch (data['message']) {
      String message when message == message.toUpperCase() => message,
      _ => null,
    };
  }

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
