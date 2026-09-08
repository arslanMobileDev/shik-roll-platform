import 'package:dio/dio.dart';

import '../storage/courier_token_storage.dart';

/// Single authorized Dio interceptor for the courier app (ADR-1617).
///
/// * Attaches `Authorization: Bearer <token>` from secure storage to every
///   request except the public login endpoint — the token is never sent as a
///   query parameter and repositories never set headers by hand.
/// * A `401` response triggers a single-flight session invalidation:
///   concurrent 401s share one [onUnauthorized] call and the failed request
///   is not retried automatically. `403` does not destroy the session.
class CourierAuthInterceptor extends Interceptor {
  CourierAuthInterceptor({
    required this._tokenStorage,
    this.onUnauthorized,
    this._unauthenticatedPaths = const ['/couriers/auth/pin'],
  });

  final CourierTokenStorage _tokenStorage;
  final List<String> _unauthenticatedPaths;

  /// Called once per invalidation burst when any request answers 401
  /// (wired to `AuthCubit.sessionExpired` by the app composition root).
  Future<void> Function()? onUnauthorized;

  Future<void>? _invalidation;

  bool _isPublic(RequestOptions options) {
    final path = options.uri.path;
    return _unauthenticatedPaths.any(path.endsWith);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options)) {
      final token = await _tokenStorage.read();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        !_isPublic(err.requestOptions) &&
        onUnauthorized != null) {
      // Single-flight: concurrent 401s collapse into one invalidation.
      _invalidation ??= onUnauthorized!().whenComplete(
        () => _invalidation = null,
      );
    }
    handler.next(err);
  }
}
