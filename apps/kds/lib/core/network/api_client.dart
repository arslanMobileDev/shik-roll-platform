import 'package:dio/dio.dart';

/// HTTP client for the SHIK Platform Kitchen API (ADR-1618 / API-709).
///
/// Thin wrapper over Dio: base URL, timeouts and JSON defaults live here so
/// repositories stay transport-agnostic. When a [tokenProvider] is given an
/// interceptor attaches the terminal JWT as `Authorization: Bearer …`; a 401
/// from any non-auth endpoint triggers [onUnauthorized] exactly once per
/// session invalidation (single-flight), so parallel requests don't fire a
/// logout storm.
final class ApiClient {
  ApiClient({
    required String baseUrl,
    String? Function()? tokenProvider,
    void Function()? onUnauthorized,
    Dio? dio,
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           ) {
    if (tokenProvider != null || onUnauthorized != null) {
      this.dio.interceptors.add(
        _KitchenAuthInterceptor(
          tokenProvider: tokenProvider,
          onUnauthorized: onUnauthorized,
        ),
      );
    }
  }

  final Dio dio;
}

final class _KitchenAuthInterceptor extends Interceptor {
  _KitchenAuthInterceptor({this.tokenProvider, this.onUnauthorized});

  final String? Function()? tokenProvider;
  final void Function()? onUnauthorized;

  /// Single-flight guard: reset only when the token itself changes (a fresh
  /// login) — re-arming on every request would report every 401 in a burst.
  bool _invalidationReported = false;
  String? _armedToken;

  bool _isAuthRequest(RequestOptions options) =>
      options.path.contains('/kitchen/auth/pin');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      if (token != _armedToken) {
        // A fresh token is in place — future 401s must be reported anew.
        _armedToken = token;
        _invalidationReported = false;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    if (status == 401 &&
        !_isAuthRequest(err.requestOptions) &&
        !_invalidationReported) {
      _invalidationReported = true;
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
