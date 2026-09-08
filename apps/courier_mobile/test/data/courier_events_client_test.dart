import 'dart:convert';
import 'dart:typed_data';

import 'package:courier_mobile/data/repositories/courier_events_client.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(String text) => utf8.encode(text);

const frameJson =
    '{"orderId":"order-1","orderNumber":"A-1","status":"ON_WAY",'
    '"branchId":"branch-center","courierId":"courier-muhammad",'
    '"timestamp":"2026-09-06T12:30:00.000Z"}';

void main() {
  group('CourierEventsClient.parseSseFrames', () {
    test('parses a data frame into a typed event', () async {
      final events = await CourierEventsClient.parseSseFrames(
        Stream.fromIterable([bytes('data: $frameJson\n\n')]),
      ).toList();

      expect(events, hasLength(1));
      expect(events.single.orderId, 'order-1');
      expect(events.single.status, 'ON_WAY');
      expect(events.single.courierId, 'courier-muhammad');
    });

    test('reassembles a frame split across byte chunks', () async {
      final full = 'data: $frameJson\n\n';
      final part1 = full.substring(0, 40);
      final part2 = full.substring(40);
      final events = await CourierEventsClient.parseSseFrames(
        Stream.fromIterable([bytes(part1), bytes(part2)]),
      ).toList();

      expect(events, hasLength(1));
      expect(events.single.orderId, 'order-1');
    });

    test('skips keep-alive comments and drops malformed JSON', () async {
      final events = await CourierEventsClient.parseSseFrames(
        Stream.fromIterable([
          bytes(': keep-alive\n\ndata: {broken json\n\ndata: $frameJson\n\n'),
        ]),
      ).toList();

      expect(events, hasLength(1));
      expect(events.single.orderId, 'order-1');
    });

    test('joins multi-line data fields per SSE spec', () async {
      // Split at a JSON token boundary: a newline after a comma is valid.
      final cut = frameJson.indexOf('"branchId"');
      final half1 = frameJson.substring(0, cut);
      final half2 = frameJson.substring(cut);
      final events = await CourierEventsClient.parseSseFrames(
        Stream.fromIterable([bytes('data: $half1\ndata: $half2\n\n')]),
      ).toList();

      expect(events, hasLength(1));
      expect(events.single.status, 'ON_WAY');
    });

    test('a trailing partial frame without boundary is not emitted', () async {
      final events = await CourierEventsClient.parseSseFrames(
        Stream.fromIterable([bytes('data: $frameJson')]),
      ).toList();

      expect(events, isEmpty);
    });
  });
}
