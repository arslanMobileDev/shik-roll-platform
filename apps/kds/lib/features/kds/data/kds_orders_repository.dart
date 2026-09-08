import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'kds_order_models.dart';

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
  Stream<void> watchOrders(String branchId);
}

/// Remote implementation against the live Orders API.
final class RemoteKdsOrdersRepository implements KdsOrdersRepository {
  RemoteKdsOrdersRepository(ApiClient client) : _client = client;

  final ApiClient _client;

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
  Stream<void> watchOrders(String branchId) async* {
    while (true) {
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
          await Future<void>.delayed(const Duration(seconds: 3));
          continue;
        }

        await for (final line in stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.startsWith('data:')) {
            yield null;
          }
        }
      } catch (_) {
        // Fallback delay on connection drop before reconnecting
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
  }
}
