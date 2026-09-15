import 'package:dio/dio.dart';

import '../auth/auth_storage.dart';
import '../auth/session_events.dart';
import '../config/api_config.dart';

/// Dio wrapper for the SHIK back-office API.
///
/// - Injects `Authorization: Bearer <staff-token>` on every request that
///   is not the public login endpoint (auth/pin).
/// - On 401 from the backend (expired or revoked token) it clears the
///   stored session and calls [onUnauthorized] so the app can route back
///   to the login screen.
final class ApiClient {
  ApiClient({String? baseUrl, void Function()? onUnauthorized})
    : onUnauthorized = onUnauthorized ?? SessionEvents.fireUnauthorized,
      dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          headers: const {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 400,
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Public endpoints: no token yet available.
          if (options.path.startsWith('/staff/auth/')) {
            return handler.next(options);
          }
          final token = await AuthStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await AuthStorage.clear();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;

  /// Fires when the backend answers 401 — the session is already cleared
  /// by the interceptor, the callback only handles routing/UI.
  final void Function()? onUnauthorized;
}
