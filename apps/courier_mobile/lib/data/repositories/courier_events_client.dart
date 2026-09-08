import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/courier_order_event.dart';

/// Authorized SSE client for GET /couriers/stream (ADR-1617).
///
/// The stream is read as a Dio byte stream with the Authorization header
/// attached by CourierAuthInterceptor — browser EventSource is not used.
/// Reconnection (backoff, REST resync) is owned by OrdersCubit; this client
/// only parses one connection's frames into typed events.
class CourierEventsClient {
  CourierEventsClient(this._dio);

  final Dio _dio;

  /// Opens the stream and yields parsed order events until the server closes
  /// the connection or an error occurs.
  Stream<CourierOrderEvent> watch() async* {
    final response = await _dio.get<ResponseBody>(
      '/couriers/stream',
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        // SSE is long-lived: no receive timeout for the stream itself.
        receiveTimeout: Duration.zero,
      ),
    );
    final body = response.data;
    if (body == null) return;
    yield* parseSseFrames(body.stream);
  }

  /// Parses the SSE wire format (`data: {json}\n\n`) into typed events.
  /// Comment/keep-alive lines and non-data fields are skipped; malformed
  /// JSON payloads are dropped, not fatal.
  static Stream<CourierOrderEvent> parseSseFrames(
    Stream<Uint8List> byteStream,
  ) async* {
    final buffer = StringBuffer();
    await for (final chunk in utf8.decoder.bind(byteStream)) {
      buffer.write(chunk);
      var text = buffer.toString();
      var boundary = text.indexOf('\n\n');
      while (boundary >= 0) {
        final frame = text.substring(0, boundary);
        text = text.substring(boundary + 2);
        buffer
          ..clear()
          ..write(text);
        final event = _parseFrame(frame);
        if (event != null) yield event;
        boundary = text.indexOf('\n\n');
      }
    }
  }

  static CourierOrderEvent? _parseFrame(String frame) {
    final dataLines = <String>[];
    for (final line in frame.split('\n')) {
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return null;
    try {
      final json = jsonDecode(dataLines.join('\n'));
      if (json is! Map<String, dynamic>) return null;
      return CourierOrderEvent.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
