import 'package:dio/dio.dart';

import '../../../core/auth/auth_token_provider.dart';
import '../../../core/network/api_client.dart';

/// Failure surfaced by the account data layer.
final class AccountException implements Exception {
  const AccountException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Backend error code when present (`ACTIVE_ORDERS_EXIST`, …).
  final String? code;

  /// 401 on an authorized call: the stored token is no longer valid.
  bool get isUnauthorized => statusCode == 401;

  /// Аккаунт уже удалён: цель достигнута, повторять запрос не нужно.
  bool get isAlreadyDeleted => code == 'ACCOUNT_ALREADY_DELETED';

  @override
  String toString() => 'AccountException($statusCode, $code): $message';
}

/// Шаг 1 удаления: что будет потеряно и одноразовый токен подтверждения.
final class DeletionRequest {
  const DeletionRequest({
    required this.deletionToken,
    required this.expiresInSeconds,
    required this.bonusBalance,
    required this.canDelete,
    this.blockedReason,
  });

  factory DeletionRequest.fromJson(Map<String, dynamic> json) =>
      DeletionRequest(
        deletionToken: json['deletionToken'] as String,
        expiresInSeconds: json['expiresInSeconds'] as int,
        bonusBalance: (json['bonusBalance'] as num).toInt(),
        canDelete: json['canDelete'] as bool,
        blockedReason: json['blockedReason'] as String?,
      );

  /// Одноразовый токен для [AccountRepository.confirmDeletion]; живёт минуты.
  final String deletionToken;
  final int expiresInSeconds;

  /// Бонусы, которые сгорят при подтверждении.
  final int bonusBalance;

  /// `false`, пока есть заказ в работе — подтверждение ответит 409.
  final bool canDelete;
  final String? blockedReason;
}

/// Шаг 2 удаления: результат.
final class DeletionResult {
  const DeletionResult({
    required this.deleted,
    required this.expiredBonusPoints,
  });

  factory DeletionResult.fromJson(Map<String, dynamic> json) => DeletionResult(
    deleted: json['deleted'] as bool,
    expiredBonusPoints: (json['expiredBonusPoints'] as num).toInt(),
  );

  final bool deleted;

  /// Фактически сгоревшая сумма: снимок шага 1 мог устареть.
  final int expiredBonusPoints;
}

/// Self-service удаление аккаунта гостя (требование Apple).
abstract interface class AccountRepository {
  /// Шаг 1 — `POST /customers/me/deletion-request` (Bearer).
  Future<DeletionRequest> requestDeletion();

  /// Шаг 2 — `POST /customers/me/deletion-confirm` (Bearer) с токеном шага 1.
  Future<DeletionResult> confirmDeletion({required String deletionToken});
}

/// Remote implementation over the Customers API contract.
final class RemoteAccountRepository implements AccountRepository {
  RemoteAccountRepository(this._client, this._tokenProvider);

  final ApiClient _client;
  final AuthTokenProvider _tokenProvider;

  @override
  Future<DeletionRequest> requestDeletion() async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/me/deletion-request',
        options: _authorized,
      );
      final data = response.data;
      if (data == null) {
        throw AccountException(
          'Пустой ответ сервера. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return DeletionRequest.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const AccountException('Некорректный ответ сервера.');
    }
  }

  @override
  Future<DeletionResult> confirmDeletion({required String deletionToken}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/me/deletion-confirm',
        data: {'deletionToken': deletionToken},
        options: _authorized,
      );
      final data = response.data;
      if (data == null) {
        throw AccountException(
          'Пустой ответ сервера. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return DeletionResult.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const AccountException('Некорректный ответ сервера.');
    }
  }

  Options get _authorized => Options(
    headers: {
      if (_tokenProvider.authorizationHeader != null)
        'Authorization': _tokenProvider.authorizationHeader,
    },
  );

  /// Translates transport and API failures into guest-readable messages.
  static AccountException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final code = _backendCode(error.response);
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => AccountException(
        'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.connectionError => AccountException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.badResponse when statusCode == 401 => AccountException(
        'Сессия истекла. Войдите ещё раз.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.badResponse when (statusCode ?? 0) >= 500 =>
        AccountException(
          'Сервис временно недоступен. Попробуйте позже.',
          statusCode: statusCode,
          code: code,
        ),
      DioExceptionType.badResponse => AccountException(
        switch (code) {
          'ACTIVE_ORDERS_EXIST' =>
            'Есть незавершённый заказ. Удаление станет доступно после его завершения.',
          'ACCOUNT_ALREADY_DELETED' => 'Аккаунт уже удалён.',
          _ =>
            _backendMessage(error.response) ??
                'Не удалось выполнить запрос. Попробуйте ещё раз.',
        },
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.cancel => AccountException(
        'Запрос отменён.',
        statusCode: statusCode,
        code: code,
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => AccountException(
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
