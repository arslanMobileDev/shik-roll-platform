import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'kds_order_models.dart';

/// Transport-level events emitted by the kitchen SSE connection.
enum KdsOrdersStreamEvent {
  connecting,
  connected,
  reconnecting,
  disconnected,
  ordersChanged,
}

/// Source of kitchen orders (API-702 `OrdersController`).
abstract interface class KdsOrdersRepository {
  /// `GET /orders?branchId=…&page=…&limit=…`
  Future<List<KdsOrder>> fetchOrders({
    required String branchId,
    int page = 1,
    int limit = 50,
  });

  /// `PATCH /orders/{id}/status`
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
    String? cookId,
    String? shiftId,
  });

  /// SSE stream: `GET /orders/kds/stream?branchId=…`
  Stream<KdsOrdersStreamEvent> watchOrders(String branchId);
}

/// Remote implementation against the live Orders API.
final class RemoteKdsOrdersRepository implements KdsOrdersRepository {
  RemoteKdsOrdersRepository(
    ApiClient client, {
    List<Duration> reconnectDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
  }) : _client = client,
       assert(reconnectDelays.isNotEmpty),
       _reconnectDelays = reconnectDelays;

  final ApiClient _client;
  final List<Duration> _reconnectDelays;

  @override
  Future<List<KdsOrder>> fetchOrders({
    required String branchId,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/orders',
      queryParameters: {'branchId': branchId, 'page': page, 'limit': limit},
    );
    final data = (response.data?['data'] as List?) ?? const [];
    return [for (final o in data) KdsOrder.fromJson(o as Map<String, dynamic>)];
  }

  @override
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
    String? cookId,
    String? shiftId,
  }) async {
    final response = await _client.dio.patch<Map<String, dynamic>>(
      '/orders/$orderId/status',
      data: {
        'status': status.wireName,
        'cookId': cookId,
        'shiftId': shiftId,
      },
    );
    final body = response.data;
    if (body == null) {
      throw StateError('Empty response for order $orderId status update');
    }
    return KdsOrder.fromJson(body);
  }

  @override
  Stream<KdsOrdersStreamEvent> watchOrders(String branchId) async* {
    var retryIndex = 0;
    var isFirstAttempt = true;

    while (true) {
      yield isFirstAttempt
          ? KdsOrdersStreamEvent.connecting
          : KdsOrdersStreamEvent.reconnecting;

      try {
        final response = await _client.dio.get<ResponseBody>(
          '/orders/kds/stream',
          queryParameters: {'branchId': branchId},
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
            receiveTimeout: Duration.zero,
          ),
        );

        final stream = response.data?.stream;
        if (stream == null) {
          throw StateError('SSE response has no stream');
        }

        yield KdsOrdersStreamEvent.connected;
        retryIndex = 0;
        isFirstAttempt = false;

        await for (final line in stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.startsWith('data:')) {
            yield KdsOrdersStreamEvent.ordersChanged;
          }
        }
      } catch (_) {
        // The board remains usable through polling; reconnect below.
      }

      yield KdsOrdersStreamEvent.disconnected;
      final delay = _reconnectDelays[retryIndex];
      if (retryIndex < _reconnectDelays.length - 1) retryIndex++;
      isFirstAttempt = false;
      await Future<void>.delayed(delay);
    }
  }
}
