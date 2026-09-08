import 'dart:convert';
import 'dart:typed_data';

import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/network/api_client.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/orders/data/order_tracking_repository.dart';
import 'package:customer_mobile/features/orders/domain/order_timeline.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

Response<ResponseBody> _sseResponse(
  List<String> chunks, {
  int statusCode = 200,
}) {
  return Response<ResponseBody>(
    data: ResponseBody(
      Stream.fromIterable(chunks.map(_bytes)),
      statusCode,
      headers: {},
    ),
    statusCode: statusCode,
    requestOptions: RequestOptions(path: ''),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  late _MockDio dio;
  late AuthTokenProvider tokenProvider;
  late RemoteOrderTrackingRepository repository;

  const orderId = 'order-uuid-1';

  setUp(() {
    dio = _MockDio();
    tokenProvider = AuthTokenProvider()..accessToken = 'token-123';
    repository = RemoteOrderTrackingRepository(
      ApiClient(baseUrl: '', dio: dio),
      tokenProvider,
    );
  });

  void stubStream(List<String> chunks, {int statusCode = 200}) {
    when(
      () => dio.get<ResponseBody>(
        '/orders/$orderId/tracking-stream',
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _sseResponse(chunks, statusCode: statusCode));
  }

  group('RemoteOrderTrackingRepository.openTrackingStream', () {
    test('парсит события из SSE-фреймов и шлёт Bearer-токен', () async {
      stubStream([
        'data: {"orderId":"order-uuid-1","status":"NEW","courierId":null,"version":1,"estimatedReadyAt":null,"timestamp":"2026-09-08T19:00:00.000Z"}\n\n'
        'data: {"orderId":"order-uuid-1","status":"COOKING","courierId":null,"version":3,"estimatedReadyAt":"2026-09-08T19:45:00.000Z","timestamp":"2026-09-08T19:10:00.000Z"}\n\n',
      ]);

      final events = await repository.openTrackingStream(orderId).toList();

      expect(events, hasLength(2));
      expect(events[0].status, 'NEW');
      expect(events[0].version, 1);
      expect(events[1].timeline.status, OrderTimelineStatus.cooking);
      expect(events[1].timeline.progressPercent, 40);

      final options =
          verify(
                () => dio.get<ResponseBody>(
                  '/orders/$orderId/tracking-stream',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.responseType, ResponseType.stream);
      expect(options.headers?['Authorization'], 'Bearer token-123');
      expect(options.headers?['Accept'], 'text/event-stream');
      // Long-lived stream без receiveTimeout.
      expect(options.receiveTimeout, Duration.zero);
    });

    test('фрейм, разрезанный между чанками, собирается корректно', () async {
      stubStream([
        'data: {"orderId":"o1","sta',
        'tus":"ON_WAY","courierId":"c-1","version":4,',
        '"estimatedReadyAt":null,"timestamp":null}\n\n',
      ]);

      final events = await repository.openTrackingStream(orderId).toList();

      expect(events, hasLength(1));
      expect(events.single.timeline.status, OrderTimelineStatus.onWay);
      expect(events.single.timeline.progressPercent, 75);
    });

    test('heartbeat-комментарии и битые кадры пропускаются', () async {
      stubStream([
        ': heartbeat\n\n',
        'data: {broken json\n\n',
        'id: evt-9\ndata: {"orderId":"o1","status":"COMPLETED","courierId":null,"version":6,"estimatedReadyAt":null,"timestamp":null}\n\n',
      ]);

      final events = await repository.openTrackingStream(orderId).toList();

      expect(events, hasLength(1));
      expect(events.single.timeline.status, OrderTimelineStatus.delivered);
    });

    test('CRLF-разделители фреймов поддерживаются', () async {
      stubStream([
        'data: {"orderId":"o1","status":"CONFIRMED","courierId":null,"version":2,"estimatedReadyAt":null,"timestamp":null}\r\n\r\n',
      ]);

      final events = await repository.openTrackingStream(orderId).toList();

      expect(events, hasLength(1));
      expect(events.single.timeline.status, OrderTimelineStatus.accepted);
    });

    test('401 → OrdersException «Сессия истекла»', () async {
      stubStream([], statusCode: 401);
      await expectLater(
        repository.openTrackingStream(orderId).toList(),
        throwsA(
          isA<OrdersException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('Сессия истекла')),
        ),
      );
    });

    test('404 → OrdersException «Заказ не найден»', () async {
      stubStream([], statusCode: 404);
      await expectLater(
        repository.openTrackingStream(orderId).toList(),
        throwsA(
          isA<OrdersException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('сетевая ошибка Dio маппится в OrdersException', () async {
      when(
        () => dio.get<ResponseBody>(
          '/orders/$orderId/tracking-stream',
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.openTrackingStream(orderId).toList(),
        throwsA(
          isA<OrdersException>().having(
            (e) => e.message,
            'message',
            contains('Нет соединения'),
          ),
        ),
      );
    });
  });

  group('RemoteOrderTrackingRepository.getOrderSnapshot', () {
    test('GET /orders/:id парсится в update без версии', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/orders/$orderId',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: const {
            'id': orderId,
            'status': 'READY',
            'estimatedReadyAt': '2026-09-08T20:15:00.000Z',
            'updatedAt': '2026-09-08T19:30:00.000Z',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final update = await repository.getOrderSnapshot(orderId);

      expect(update.orderId, orderId);
      expect(update.version, isNull);
      // READY без курьера — клиентская проекция остаётся COOKING (40%).
      expect(update.timeline.status, OrderTimelineStatus.cooking);
      expect(update.timeline.progressPercent, 40);
      expect(update.timeline.estimatedDeliveryAt, isNotNull);
    });

    test('пустой ответ → OrdersException', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/orders/$orderId',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await expectLater(
        repository.getOrderSnapshot(orderId),
        throwsA(isA<OrdersException>()),
      );
    });
  });
}
