import { OrderStatus } from '@prisma/client';
import { CouriersEventsService, OrderTrackingEvent } from './couriers-events.service';

const ORDER_A = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const ORDER_B = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

function makeTrackingEvent(orderId: string, status: OrderStatus, version = 1): OrderTrackingEvent {
  return {
    orderId,
    status,
    courierId: null,
    version,
    estimatedReadyAt: null,
    timestamp: new Date().toISOString(),
  };
}

describe('CouriersEventsService', () => {
  let service: CouriersEventsService;

  beforeEach(() => {
    service = new CouriersEventsService();
  });

  describe('getOrderTrackingStream', () => {
    it('delivers every status change of the subscribed order', () => {
      const received: OrderTrackingEvent[] = [];
      const subscription = service
        .getOrderTrackingStream(ORDER_A)
        .subscribe((message) => received.push(message.data as OrderTrackingEvent));

      const statuses = [
        OrderStatus.NEW,
        OrderStatus.CONFIRMED,
        OrderStatus.COOKING,
        OrderStatus.READY,
        OrderStatus.ON_WAY,
        OrderStatus.COMPLETED,
        OrderStatus.CANCELLED,
      ];
      statuses.forEach((status, index) =>
        service.emitOrderTrackingEvent(makeTrackingEvent(ORDER_A, status, index + 1)),
      );
      subscription.unsubscribe();

      expect(received.map((event) => event.status)).toEqual(statuses);
      expect(received.map((event) => event.version)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    });

    it('does not leak events of other orders to the subscriber', () => {
      const received: OrderTrackingEvent[] = [];
      const subscription = service
        .getOrderTrackingStream(ORDER_A)
        .subscribe((message) => received.push(message.data as OrderTrackingEvent));

      service.emitOrderTrackingEvent(makeTrackingEvent(ORDER_B, OrderStatus.CONFIRMED));
      service.emitOrderTrackingEvent(makeTrackingEvent(ORDER_A, OrderStatus.COOKING));
      service.emitOrderTrackingEvent(makeTrackingEvent(ORDER_B, OrderStatus.ON_WAY));
      subscription.unsubscribe();

      expect(received).toHaveLength(1);
      expect(received[0]).toMatchObject({ orderId: ORDER_A, status: OrderStatus.COOKING });
    });

    it('fans out one order’s events to multiple subscribers independently', () => {
      const first: OrderTrackingEvent[] = [];
      const second: OrderTrackingEvent[] = [];
      const subA = service
        .getOrderTrackingStream(ORDER_A)
        .subscribe((message) => first.push(message.data as OrderTrackingEvent));
      const subB = service
        .getOrderTrackingStream(ORDER_A)
        .subscribe((message) => second.push(message.data as OrderTrackingEvent));

      service.emitOrderTrackingEvent(makeTrackingEvent(ORDER_A, OrderStatus.READY));
      subA.unsubscribe();
      service.emitOrderTrackingEvent(makeTrackingEvent(ORDER_A, OrderStatus.ON_WAY));
      subB.unsubscribe();

      expect(first).toHaveLength(1);
      expect(second).toHaveLength(2);
    });

    it('stays silent for late subscribers (no replay of past events)', () => {
      service.emitOrderTrackingEvent(makeTrackingEvent(ORDER_A, OrderStatus.CONFIRMED));

      const received: OrderTrackingEvent[] = [];
      const subscription = service
        .getOrderTrackingStream(ORDER_A)
        .subscribe((message) => received.push(message.data as OrderTrackingEvent));
      subscription.unsubscribe();

      expect(received).toHaveLength(0);
    });
  });
});
