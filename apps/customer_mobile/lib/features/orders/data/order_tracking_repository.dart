import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/auth/auth_token_provider.dart';
import '../../../core/network/api_client.dart';
import '../../cart/data/orders_repository.dart';
import '../domain/order_timeline.dart';

/// Realtime-обновления статуса заказа для гостя (ADR-1615).
abstract interface class OrderTrackingRepository {
  /// Snapshot текущего состояния (`GET /orders/{id}`).
  Future<OrderTrackingUpdate> getOrderSnapshot(String orderId);

  /// SSE-стрим `GET /orders/{id}/tracking-stream`. Первое событие —
  /// snapshot, далее событие на каждый переход статуса. Ошибки транспорта
  /// завершают стрим [OrdersException] — их обрабатывает bloc.
  Stream<OrderTrackingUpdate> openTrackingStream(String orderId);
}

/// Remote implementation over the Orders API contract (Bearer token гостя).
final class RemoteOrderTrackingRepository implements OrderTrackingRepository {
  RemoteOrderTrackingRepository(this._client, this._tokenProvider);

  final ApiClient _client;
  final AuthTokenProvider _tokenProvider;

  Map<String, String> get _authHeaders => {
    if (_tokenProvider.authorizationHeader != null)
      'Authorization': _tokenProvider.authorizationHeader!,
  };

  @override
  Future<OrderTrackingUpdate> getOrderSnapshot(String orderId) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/orders/$orderId',
        options: Options(headers: _authHeaders),
      );
      final data = response.data;
      if (data == null) {
        throw OrdersException(
          'Пустой ответ сервера. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return OrderTrackingUpdate.fromOrderJson(data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const OrdersException(
        'Некорректный ответ сервера. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Stream<OrderTrackingUpdate> openTrackingStream(String orderId) async* {
    final Response<ResponseBody> response;
    try {
      response = await _client.dio.get<ResponseBody>(
        '/orders/$orderId/tracking-stream',
        options: Options(
          responseType: ResponseType.stream,
          // Long-lived stream: таймаут приёма не применяем, иначе Dio
          // оборвал бы соединение в паузах между событиями.
          receiveTimeout: Duration.zero,
          headers: {'Accept': 'text/event-stream', ..._authHeaders},
        ),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 401) {
      throw const OrdersException(
        'Сессия истекла. Войдите ещё раз, чтобы следить за заказом.',
        statusCode: 401,
      );
    }
    if (statusCode == 404) {
      throw const OrdersException('Заказ не найден.', statusCode: 404);
    }
    if (statusCode != 200) {
      throw OrdersException(
        'Не удалось подключиться к обновлениям заказа. Попробуйте ещё раз.',
        statusCode: statusCode,
      );
    }
    final body = response.data;
    if (body == null) {
      throw const OrdersException('Пустой ответ сервера. Попробуйте ещё раз.');
    }
    yield* decodeSseStream(body.stream);
  }

  /// Разбор SSE-фреймов (`data: {json}\n\n`) с инкрементальным буфером:
  /// фрейм может быть разрезан между сетевыми чанками. Строки-комментарии
  /// (`:heartbeat`) и служебные поля (`event:`, `id:`, `retry:`) пропускаем,
  /// битый JSON в кадре игнорируем — стрим живёт дальше.
  static Stream<OrderTrackingUpdate> decodeSseStream(
    Stream<Uint8List> byteStream,
  ) async* {
    var carry = '';
    // .cast нормализует reified-тип чанков: utf8.decoder принимает
    // только StreamTransformer<List<int>, String>, а Dio отдаёт
    // Stream<Uint8List> — без cast проверка типов падает в рантайме.
    await for (final chunk in byteStream.cast<List<int>>().transform(
      utf8.decoder,
    )) {
      carry += chunk;
      while (true) {
        final boundary = _frameBoundary(carry);
        if (boundary == null) break;
        final frame = carry.substring(0, boundary.$1);
        carry = carry.substring(boundary.$1 + boundary.$2);
        final update = _parseFrame(frame);
        if (update != null) yield update;
      }
    }
  }

  /// (index, length) конца фрейма: `\n\n` или `\r\n\r\n`, что раньше.
  static (int, int)? _frameBoundary(String text) {
    final lf = text.indexOf('\n\n');
    final crlf = text.indexOf('\r\n\r\n');
    if (lf == -1 && crlf == -1) return null;
    if (crlf == -1 || (lf != -1 && lf < crlf)) return (lf, 2);
    return (crlf, 4);
  }

  static OrderTrackingUpdate? _parseFrame(String frame) {
    final dataLines = <String>[];
    for (final line in frame.split('\n')) {
      if (line.startsWith('data:')) {
        final value = line.substring(5);
        dataLines.add(value.startsWith(' ') ? value.substring(1) : value);
      }
    }
    if (dataLines.isEmpty) return null;
    try {
      final json = jsonDecode(dataLines.join('\n')) as Map<String, dynamic>;
      return OrderTrackingUpdate.fromTrackingEvent(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Translates transport failures into a message the guest can act on.
  static OrdersException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => OrdersException(
        'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        statusCode: statusCode,
      ),
      DioExceptionType.connectionError => OrdersException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when statusCode == 401 => OrdersException(
        'Сессия истекла. Войдите ещё раз, чтобы следить за заказом.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when statusCode == 404 => OrdersException(
        'Заказ не найден.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when (statusCode ?? 0) >= 500 =>
        OrdersException(
          'Сервер временно недоступен. Попробуйте позже.',
          statusCode: statusCode,
        ),
      DioExceptionType.badResponse => OrdersException(
        'Не удалось загрузить статус заказа. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.cancel => OrdersException(
        'Загрузка отменена.',
        statusCode: statusCode,
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => OrdersException(
        'Ошибка сети при загрузке статуса заказа. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
    };
  }
}

/// In-memory трекинг для разработки и тестов: воспроизводит демо-сценарий
/// смены статусов заказа с нарастающими версиями.
final class FakeOrderTrackingRepository implements OrderTrackingRepository {
  FakeOrderTrackingRepository({
    this.latency = const Duration(milliseconds: 300),
    this.stepDelay = const Duration(seconds: 4),
    List<String>? script,
  }) : _script = script ?? _defaultScript;

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  /// Пауза между событиями демо-стрима.
  final Duration stepDelay;

  final List<String> _script;

  static const _defaultScript = <String>[
    'NEW',
    'CONFIRMED',
    'COOKING',
    'READY',
    'ON_WAY',
    'COMPLETED',
  ];

  OrderTrackingUpdate _update(int index) => OrderTrackingUpdate(
    orderId: 'demo-order',
    status: _script[index],
    // Курьер «назначается» на шаге READY.
    courierId: _script[index] == 'READY' || _script[index] == 'ON_WAY'
        ? 'demo-courier'
        : null,
    version: index + 1,
    estimatedReadyAt: DateTime.now().add(const Duration(minutes: 35)),
    timestamp: DateTime.now(),
  );

  @override
  Future<OrderTrackingUpdate> getOrderSnapshot(String orderId) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _update(0);
  }

  @override
  Stream<OrderTrackingUpdate> openTrackingStream(String orderId) async* {
    // Первым событием сервер присылает snapshot текущего состояния.
    yield _update(0);
    for (var i = 1; i < _script.length; i++) {
      await Future<void>.delayed(stepDelay);
      yield _update(i);
    }
  }
}
