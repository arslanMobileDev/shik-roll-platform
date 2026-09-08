import 'package:customer_mobile/features/orders/domain/order_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderTimeline.fromBackendStatus (ADR-1615 projection)', () {
    test('NEW → PENDING 5%', () {
      final timeline = OrderTimeline.fromBackendStatus('NEW');
      expect(timeline.status, OrderTimelineStatus.pending);
      expect(timeline.progressPercent, 5);
      expect(timeline.isCancelled, isFalse);
    });

    test('CONFIRMED → ACCEPTED 15%', () {
      final timeline = OrderTimeline.fromBackendStatus('CONFIRMED');
      expect(timeline.status, OrderTimelineStatus.accepted);
      expect(timeline.progressPercent, 15);
    });

    test('COOKING → COOKING 40%', () {
      final timeline = OrderTimeline.fromBackendStatus('COOKING');
      expect(timeline.status, OrderTimelineStatus.cooking);
      expect(timeline.progressPercent, 40);
    });

    test('READY без курьера остаётся COOKING 40%', () {
      final timeline = OrderTimeline.fromBackendStatus('READY');
      expect(timeline.status, OrderTimelineStatus.cooking);
      expect(timeline.progressPercent, 40);
    });

    test('READY с назначенным курьером → COURIER_ASSIGNED 55%', () {
      final timeline = OrderTimeline.fromBackendStatus(
        'READY',
        courierId: 'courier-1',
      );
      expect(timeline.status, OrderTimelineStatus.courierAssigned);
      expect(timeline.progressPercent, 55);
    });

    test('ON_WAY → ON_WAY 75%', () {
      final timeline = OrderTimeline.fromBackendStatus('ON_WAY');
      expect(timeline.status, OrderTimelineStatus.onWay);
      expect(timeline.progressPercent, 75);
    });

    test('COMPLETED → DELIVERED 100%', () {
      final timeline = OrderTimeline.fromBackendStatus('COMPLETED');
      expect(timeline.status, OrderTimelineStatus.delivered);
      expect(timeline.progressPercent, 100);
    });

    test('CANCELLED — терминальное состояние без процента', () {
      final timeline = OrderTimeline.fromBackendStatus('CANCELLED');
      expect(timeline.status, isNull);
      expect(timeline.isCancelled, isTrue);
      expect(timeline.progressPercent, 0);
    });

    test('неизвестный статус → безопасный PENDING 5%', () {
      final timeline = OrderTimeline.fromBackendStatus('SOME_FUTURE_STATUS');
      expect(timeline.status, OrderTimelineStatus.pending);
      expect(timeline.progressPercent, 5);
    });

    test('версия и ETA пробрасываются в проекцию', () {
      final eta = DateTime.utc(2026, 9, 8, 19, 45);
      final timeline = OrderTimeline.fromBackendStatus(
        'COOKING',
        orderVersion: 4,
        estimatedDeliveryAt: eta,
      );
      expect(timeline.orderVersion, 4);
      expect(timeline.estimatedDeliveryAt, eta);
    });
  });

  group('OrderTrackingUpdate', () {
    test('парсит payload SSE-события', () {
      final update = OrderTrackingUpdate.fromTrackingEvent(const {
        'orderId': 'order-1',
        'status': 'ON_WAY',
        'courierId': 'courier-9',
        'version': 5,
        'estimatedReadyAt': '2026-09-08T19:45:00.000Z',
        'timestamp': '2026-09-08T19:10:00.000Z',
      });
      expect(update.orderId, 'order-1');
      expect(update.version, 5);
      expect(update.timeline.status, OrderTimelineStatus.onWay);
      expect(
        update.timeline.estimatedDeliveryAt,
        DateTime.utc(2026, 9, 8, 19, 45),
      );
      expect(update.timeline.updatedAt, DateTime.utc(2026, 9, 8, 19, 10));
    });

    test('парсит payload OrderEntity (snapshot GET /orders/:id)', () {
      final update = OrderTrackingUpdate.fromOrderJson(const {
        'id': 'order-2',
        'status': 'COOKING',
        'estimatedReadyAt': '2026-09-08T20:00:00.000Z',
        'updatedAt': '2026-09-08T19:15:00.000Z',
      });
      expect(update.orderId, 'order-2');
      // В контракте OrderEntity нет версии — дедупликация по проекции.
      expect(update.version, isNull);
      expect(update.timeline.status, OrderTimelineStatus.cooking);
    });

    test('битый payload — FormatException', () {
      expect(
        () => OrderTrackingUpdate.fromTrackingEvent(const {'foo': 1}),
        throwsFormatException,
      );
    });
  });
}
