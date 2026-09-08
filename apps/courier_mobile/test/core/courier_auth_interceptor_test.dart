import 'dart:async';

import 'package:courier_mobile/core/network/courier_auth_interceptor.dart';
import 'package:courier_mobile/core/storage/courier_token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

RequestOptions request(String path) => RequestOptions(path: path);

/// The interceptor forwards errors via `handler.next(err)`; swallow the
/// resulting future so it does not become an unhandled async error.
ErrorInterceptorHandler swallowingHandler() {
  final handler = ErrorInterceptorHandler();
  unawaited(
    // ignore: invalid_use_of_protected_member
    handler.future.then<void>((_) {}, onError: (_) {}),
  );
  return handler;
}

DioException dioError(String path, int statusCode) => DioException(
  requestOptions: request(path),
  response: Response<void>(
    requestOptions: request(path),
    statusCode: statusCode,
  ),
);

void main() {
  group('CourierAuthInterceptor.onRequest', () {
    test('attaches the Bearer token to guarded requests', () async {
      final tokens = InMemoryCourierTokenStorage();
      await tokens.write('jwt-123');
      final interceptor = CourierAuthInterceptor(tokenStorage: tokens);
      final options = request('/couriers/orders/active');

      await interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['Authorization'], 'Bearer jwt-123');
    });

    test('never sends the token to the public PIN login endpoint', () async {
      final tokens = InMemoryCourierTokenStorage();
      await tokens.write('jwt-123');
      final interceptor = CourierAuthInterceptor(tokenStorage: tokens);
      final options = request('/couriers/auth/pin');

      await interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('omits the header when no token is stored', () async {
      final interceptor = CourierAuthInterceptor(
        tokenStorage: InMemoryCourierTokenStorage(),
      );
      final options = request('/couriers/orders/active');

      await interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('CourierAuthInterceptor.onError', () {
    test('401 triggers a single-flight session invalidation', () async {
      var calls = 0;
      final gate = Completer<void>();
      final interceptor = CourierAuthInterceptor(
        tokenStorage: InMemoryCourierTokenStorage(),
        onUnauthorized: () {
          calls++;
          return gate.future;
        },
      );
      // Two concurrent 401s collapse into one invalidation call.
      interceptor.onError(
        dioError('/couriers/orders/active', 401),
        swallowingHandler(),
      );
      interceptor.onError(dioError('/couriers/location', 401), swallowingHandler());
      expect(calls, 1);

      gate.complete();
      await Future<void>.delayed(Duration.zero);

      // After the invalidation completes, the next 401 invalidates again.
      interceptor.onError(
        dioError('/couriers/orders/active', 401),
        swallowingHandler(),
      );
      expect(calls, 2);
    });

    test('401 on the public login endpoint does not invalidate', () {
      var calls = 0;
      final interceptor = CourierAuthInterceptor(
        tokenStorage: InMemoryCourierTokenStorage(),
        onUnauthorized: () async => calls++,
      );

      interceptor.onError(
        dioError('/couriers/auth/pin', 401),
        swallowingHandler(),
      );
      expect(calls, 0);
    });

    test('403 does not destroy the session', () {
      var calls = 0;
      final interceptor = CourierAuthInterceptor(
        tokenStorage: InMemoryCourierTokenStorage(),
        onUnauthorized: () async => calls++,
      );

      interceptor.onError(
        dioError('/couriers/orders/1/status', 403),
        swallowingHandler(),
      );
      expect(calls, 0);
    });
  });
}
