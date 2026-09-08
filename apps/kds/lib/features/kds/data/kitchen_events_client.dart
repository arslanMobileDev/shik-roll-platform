import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/network/api_client.dart';
import 'kds_order_models.dart';

/// Typed signal from the kitchen SSE stream (API-709 `GET /kitchen/stream`).
///
/// Reconnection policy (backoff, polling fallback, snapshot on reconnect)
/// lives in the bloc — this client is one connection lifetime only.
sealed class KitchenStreamSignal extends Equatable {
  const KitchenStreamSignal();

  @override
  List<Object?> get props => [];
}

/// The server accepted the stream (HTTP 200, headers flushed).
final class KitchenStreamConnected extends KitchenStreamSignal {
  const KitchenStreamConnected();
}

/// `kitchen.order.upserted` — an order entered the board or changed.
final class KitchenOrderUpserted extends KitchenStreamSignal {
  const KitchenOrderUpserted({
    required this.order,
    required this.orderVersion,
    required this.eventId,
  });

  final KdsOrder order;
  final int orderVersion;
  final String eventId;

  @override
  List<Object?> get props => [order, orderVersion, eventId];
}

/// `kitchen.order.removed` — the order left the board (COMPLETED, CANCELLED,
/// ON_WAY, …). `order` is null on the wire.
final class KitchenOrderRemoved extends KitchenStreamSignal {
  const KitchenOrderRemoved({
    required this.orderId,
    required this.orderVersion,
    required this.eventId,
  });

  final String orderId;
  final int orderVersion;
  final String eventId;

  @override
  List<Object?> get props => [orderId, orderVersion, eventId];
}

/// Keep-alive frame (contract: at least every 20 s) carrying the server
/// clock for client offset correction.
final class KitchenStreamHeartbeat extends KitchenStreamSignal {
  const KitchenStreamHeartbeat(this.serverTime);

  final DateTime serverTime;

  @override
  List<Object?> get props => [serverTime];
}

/// Source of the branch-scoped kitchen realtime stream (ADR-1618).
abstract interface class KitchenEventsClient {
  /// One SSE connection lifetime: emits [KitchenStreamConnected] once the
  /// server accepted the stream, then order/heartbeat signals, and completes
  /// (or errors) when the connection drops.
  Stream<KitchenStreamSignal> connect();
}

/// Incremental SSE wire decoder: byte chunks → typed signals.
///
/// Handles frames split across network chunks, `\r\n` line endings, comment
/// lines (`:…`) and multi-line `data:` fields. Malformed frames are skipped —
/// a single bad payload must never kill the board stream.
final class KitchenSseDecoder
    extends StreamTransformerBase<List<int>, KitchenStreamSignal> {
  const KitchenSseDecoder();

  @override
  Stream<KitchenStreamSignal> bind(Stream<List<int>> stream) {
    late StreamController<KitchenStreamSignal> controller;
    final buffer = StringBuffer();
    String? eventName;
    final dataLines = <String>[];

    void dispatchFrame() {
      final name = eventName;
      final data = dataLines.join('\n');
      eventName = null;
      dataLines.clear();
      if (name == null || data.isEmpty) return;
      final signal = _toSignal(name, data);
      if (signal != null && !controller.isClosed) controller.add(signal);
    }

    void processText(String chunk) {
      buffer.write(chunk);
      final text = buffer.toString();
      var lineStart = 0;
      for (var i = 0; i < text.length; i++) {
        if (text[i] != '\n') continue;
        var line = text.substring(lineStart, i);
        lineStart = i + 1;
        if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
        if (line.isEmpty) {
          dispatchFrame();
        } else if (line.startsWith(':')) {
          // SSE comment — ignore.
        } else if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }
      buffer
        ..clear()
        ..write(text.substring(lineStart));
    }

    controller = StreamController<KitchenStreamSignal>(
      onListen: () {
        final subscription = stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
              processText,
              onError: controller.addError,
              onDone: () {
                dispatchFrame();
                controller.close();
              },
            );
        controller.onCancel = subscription.cancel;
      },
    );
    return controller.stream;
  }

  static KitchenStreamSignal? _toSignal(String name, String data) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return null;
      json = decoded;
    } on FormatException {
      return null;
    }
    return switch (name) {
      'kitchen.order.upserted' => switch (json['order']) {
        final Map<String, dynamic> orderJson => KitchenOrderUpserted(
          order: KdsOrder.fromJson(orderJson),
          orderVersion: (json['orderVersion'] as num?)?.toInt() ?? 0,
          eventId: json['eventId'] as String? ?? '',
        ),
        _ => null,
      },
      'kitchen.order.removed' => KitchenOrderRemoved(
        orderId: json['orderId'] as String? ?? '',
        orderVersion: (json['orderVersion'] as num?)?.toInt() ?? 0,
        eventId: json['eventId'] as String? ?? '',
      ),
      'heartbeat' => KitchenStreamHeartbeat(
        DateTime.tryParse(
              json['serverTime'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now(),
      ),
      _ => null,
    };
  }
}

/// Live implementation against `GET /kitchen/stream` (API-709).
final class HttpKitchenEventsClient implements KitchenEventsClient {
  HttpKitchenEventsClient(ApiClient client) : _client = client;

  final ApiClient _client;

  @override
  Stream<KitchenStreamSignal> connect() async* {
    final response = await _client.dio.get<ResponseBody>(
      '/kitchen/stream',
      options: Options(
        responseType: ResponseType.stream,
        // The stream is long-lived; server heartbeats keep it warm.
        receiveTimeout: Duration.zero,
        headers: const {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
      ),
    );
    yield const KitchenStreamConnected();
    final body = response.data;
    if (body == null) return;
    // `Stream<Uint8List>` upcast: the decoder accepts any byte list.
    yield* body.stream
        .cast<List<int>>()
        .transform(const KitchenSseDecoder());
  }
}

/// Demo-mode stream (API_BASE_URL unset): connects and stays silent — the
/// demo board is fully driven by the local repository.
final class FakeKitchenEventsClient implements KitchenEventsClient {
  const FakeKitchenEventsClient();

  @override
  Stream<KitchenStreamSignal> connect() async* {
    yield const KitchenStreamConnected();
    // Never completes on its own; cancellation ends it.
    await Completer<void>().future;
  }
}
