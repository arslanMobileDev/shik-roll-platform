import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/data/kitchen_events_client.dart';

List<int> chunk(String text) => utf8.encode(text);

Future<List<KitchenStreamSignal>> decode(List<List<int>> chunks) =>
    Stream.fromIterable(chunks)
        .transform(const KitchenSseDecoder())
        .toList();

const upsertFrame = '''
event: kitchen.order.upserted
data: {"eventId":"evt-1","eventType":"kitchen.order.upserted","eventVersion":1,"occurredAt":"2026-09-08T10:05:00.000Z","orderId":"order-1","orderVersion":5,"order":{"id":"order-1","orderNumber":"2042","version":5,"status":"COOKING","type":"DINE_IN","tableNumber":"7","comment":null,"confirmedAt":"2026-09-08T10:00:00.000Z","cookingStartedAt":"2026-09-08T10:05:00.000Z","readyAt":null,"items":[{"id":"item-1","name":"Филадельфия","quantity":2,"comment":null,"modifiers":[{"id":"mod-1","name":"Икра","quantity":1}]}]}}

''';

void main() {
  group('KitchenSseDecoder', () {
    test('parses an upsert frame into a typed signal', () async {
      final signals = await decode([chunk(upsertFrame)]);

      expect(signals, hasLength(1));
      final signal = signals.single as KitchenOrderUpserted;
      expect(signal.eventId, 'evt-1');
      expect(signal.orderVersion, 5);
      expect(signal.order.id, 'order-1');
      expect(signal.order.orderNumber, '2042');
      expect(signal.order.version, 5);
      expect(signal.order.status, KdsOrderStatus.cooking);
      expect(signal.order.type, KdsOrderType.dineIn);
      expect(signal.order.tableNumber, '7');
      expect(signal.order.items.single.name, 'Филадельфия');
      expect(signal.order.items.single.modifiers.single.name, 'Икра');
    });

    test('parses a removal frame (order is null on the wire)', () async {
      final signals = await decode([
        chunk(
          'event: kitchen.order.removed\n'
          'data: {"eventId":"evt-9","eventType":"kitchen.order.removed","eventVersion":1,"occurredAt":"2026-09-08T10:20:00.000Z","orderId":"order-9","orderVersion":7,"order":null}\n'
          '\n',
        ),
      ]);

      final signal = signals.single as KitchenOrderRemoved;
      expect(signal.orderId, 'order-9');
      expect(signal.orderVersion, 7);
      expect(signal.eventId, 'evt-9');
    });

    test('parses a heartbeat frame with serverTime', () async {
      final signals = await decode([
        chunk(
          'event: heartbeat\n'
          'data: {"serverTime":"2026-09-08T10:15:00.000Z"}\n'
          '\n',
        ),
      ]);

      final signal = signals.single as KitchenStreamHeartbeat;
      expect(signal.serverTime, DateTime.utc(2026, 9, 8, 10, 15).toLocal());
    });

    test('a frame split across network chunks is reassembled', () async {
      final bytes = chunk(upsertFrame);
      final cut = bytes.length ~/ 2;
      final signals = await decode([
        bytes.sublist(0, cut),
        bytes.sublist(cut),
      ]);

      expect(signals, hasLength(1));
      expect(signals.single, isA<KitchenOrderUpserted>());
    });

    test('multiple frames in one chunk produce multiple signals', () async {
      final signals = await decode([
        chunk(
          'event: heartbeat\n'
          'data: {"serverTime":"2026-09-08T10:15:00.000Z"}\n'
          '\n'
          '$upsertFrame',
        ),
      ]);

      expect(signals, hasLength(2));
      expect(signals[0], isA<KitchenStreamHeartbeat>());
      expect(signals[1], isA<KitchenOrderUpserted>());
    });

    test('comment lines and CRLF endings are handled', () async {
      final signals = await decode([
        chunk(
          ': stream opened\r\n'
          'event: heartbeat\r\n'
          'data: {"serverTime":"2026-09-08T10:15:00.000Z"}\r\n'
          '\r\n',
        ),
      ]);

      expect(signals, hasLength(1));
      expect(signals.single, isA<KitchenStreamHeartbeat>());
    });

    test('malformed JSON frames are skipped without killing the stream', () async {
      final signals = await decode([
        chunk(
          'event: kitchen.order.upserted\n'
          'data: {not-json\n'
          '\n'
          '$upsertFrame',
        ),
      ]);

      expect(signals, hasLength(1));
      expect(signals.single, isA<KitchenOrderUpserted>());
    });

    test('unknown event types are skipped', () async {
      final signals = await decode([
        chunk(
          'event: kitchen.order.unknown\n'
          'data: {"foo":1}\n'
          '\n',
        ),
      ]);

      expect(signals, isEmpty);
    });
  });
}
