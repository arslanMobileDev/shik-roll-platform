import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/network/api_client.dart';

/// Scripted adapter: answers every request with the same status/body and
/// records the final request headers.
final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({required this.statusCode, this.body = const {}});

  final int statusCode;
  final Object body;
  final List<Map<String, dynamic>> requestHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestHeaders.add(options.headers);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient auth interceptor (ADR-1618)', () {
    test('attaches the Bearer token from the provider', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        body: {'ok': true},
      );
      final client = ApiClient(
        baseUrl: 'http://test',
        tokenProvider: () => 'jwt-abc',
      )..dio.httpClientAdapter = adapter;

      await client.dio.get<Map<String, dynamic>>('/kitchen/orders/active');

      expect(adapter.requestHeaders.single['Authorization'], 'Bearer jwt-abc');
    });

    test('no token → no Authorization header', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        body: {'ok': true},
      );
      final client = ApiClient(
        baseUrl: 'http://test',
        tokenProvider: () => null,
      )..dio.httpClientAdapter = adapter;

      await client.dio.get<Map<String, dynamic>>('/kitchen/orders/active');

      expect(
        adapter.requestHeaders.single.containsKey('Authorization'),
        isFalse,
      );
    });

    test(
      'a 401 reports session invalidation exactly once (single-flight)',
      () async {
        final adapter = FakeHttpClientAdapter(statusCode: 401);
        var invalidations = 0;
        final client = ApiClient(
          baseUrl: 'http://test',
          tokenProvider: () => 'jwt-abc',
          onUnauthorized: () => invalidations++,
        )..dio.httpClientAdapter = adapter;

        for (var i = 0; i < 3; i++) {
          await expectLater(
            client.dio.get<Map<String, dynamic>>('/kitchen/orders/active'),
            throwsA(isA<DioException>()),
          );
        }

        expect(invalidations, 1);
      },
    );

    test('a fresh token re-arms invalidation reporting', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 401);
      var invalidations = 0;
      var token = 'jwt-old';
      final client = ApiClient(
        baseUrl: 'http://test',
        tokenProvider: () => token,
        onUnauthorized: () => invalidations++,
      )..dio.httpClientAdapter = adapter;

      await expectLater(
        client.dio.get<Map<String, dynamic>>('/kitchen/orders/active'),
        throwsA(isA<DioException>()),
      );
      expect(invalidations, 1);

      // Re-login: new token arrives, a later 401 must be reported again.
      token = 'jwt-new';
      await expectLater(
        client.dio.get<Map<String, dynamic>>('/kitchen/orders/active'),
        throwsA(isA<DioException>()),
      );
      expect(invalidations, 2);
      expect(adapter.requestHeaders.last['Authorization'], 'Bearer jwt-new');
    });

    test(
      '401 from the PIN login endpoint is NOT a session invalidation',
      () async {
        final adapter = FakeHttpClientAdapter(statusCode: 401);
        var invalidations = 0;
        final client = ApiClient(
          baseUrl: 'http://test',
          tokenProvider: () => null,
          onUnauthorized: () => invalidations++,
        )..dio.httpClientAdapter = adapter;

        await expectLater(
          client.dio.post<Map<String, dynamic>>(
            '/kitchen/auth/pin',
            data: {'terminalCode': 'KDS-01', 'pin': '0000'},
          ),
          throwsA(isA<DioException>()),
        );

        expect(invalidations, 0);
      },
    );
  });
}
