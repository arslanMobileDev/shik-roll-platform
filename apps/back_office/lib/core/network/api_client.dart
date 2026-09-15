import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_storage.dart';
import '../auth/session_events.dart';
import '../config/api_config.dart';

/// Dio wrapper for the SHIK back-office API.
///
/// - Injects `Authorization: Bearer <staff-token>` on every non-login call.
/// - Blocks requests that would go out without a token (explicit failure).
/// - Logs a compact diagnostic line in debug builds (never the token).
/// - Does NOT clear the session on 401: a single failing endpoint (e.g. a
///   customer-scoped route) must not log the user out of the whole panel.
final class ApiClient {
  ApiClient({
    String? baseUrl,
    void Function()? onUnauthorized,
    this.diagnostics = kDebugMode,
  })  : onUnauthorized = onUnauthorized ?? SessionEvents.fireUnauthorized,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            headers: const {'Content-Type': 'application/json'},
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final api = Uri.parse(dio.options.baseUrl);

            if (options.uri.origin != api.origin) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'UNEXPECTED_API_ORIGIN',
                  message: 'Запрос направлен на другой API origin',
                ),
              );
              return;
            }

            options.headers.removeWhere(
              (key, _) => key.toLowerCase() == 'authorization',
            );

            if (_isLogin(options)) {
              handler.next(options);
              return;
            }

            final token = (await AuthStorage.getToken())?.trim();
            final hasToken = token != null && token.isNotEmpty;

            _log('${options.method} ${options.uri.path} tokenPresent=$hasToken');

            if (!hasToken) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'STAFF_TOKEN_MISSING',
                  message: 'Нет токена сотрудника. Войдите повторно.',
                ),
              );
              return;
            }

            options.headers['Authorization'] = 'Bearer $token';
            _log('${options.method} ${options.uri.path} authorizationAttached=true');

            handler.next(options);
          } catch (_) {
            _log('Подготовка авторизации завершилась ошибкой');
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'STAFF_AUTH_PREPARATION_FAILED',
                message: 'Не удалось подготовить авторизацию запроса',
              ),
            );
          }
        },
        onError: (error, handler) {
          final options = error.requestOptions;
          final hadAuthorization = options.headers.entries.any(
            (entry) =>
                entry.key.toLowerCase() == 'authorization' &&
                entry.value is String &&
                (entry.value as String).isNotEmpty,
          );

          _log(
            '${options.method} ${options.uri.path} '
            'status=${error.response?.statusCode} '
            'authorizationAtDio=$hadAuthorization '
            'errorType=${error.type.name}',
          );

          // НЕ очищаем сессию на 401 — один упавший эндпоинт (например,
          // customer-scoped /orders) не должен разлогинивать всю панель.
          // Реальный logout — только по кнопке или после явного /staff/me 401.
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final void Function()? onUnauthorized;
  final bool diagnostics;

  static bool _isLogin(RequestOptions options) {
    final path = options.uri.path.replaceFirst(RegExp(r'/+$'), '');
    return options.method.toUpperCase() == 'POST' &&
        (path == '/staff/auth/pin' || path == '/api/staff/auth/pin');
  }

  void _log(String message) {
    if (diagnostics) {
      debugPrint('[StaffApi:${identityHashCode(this)}] $message');
    }
  }
}
