import { OrderStatus } from '@prisma/client';
import { Subscription } from 'rxjs';
import {
  CourierOrderEvent,
  CouriersEventsService,
  OrderTrackingEvent,
} from './couriers-events.service';
import { KITCHEN_SSE_HEARTBEAT_MS } from '../kitchen/kitchen.config';

const ORDER_A = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const ORDER_B = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const BRANCH_ID = 'branch-1';
const TENANT_ID = 'tenant-1';

/** Active by default: an unconfigured mock would read as "no such tenant". */
const activeTenant = { status: 'ACTIVE', deletedAt: null };

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

function makeOrderEvent(branchId: string, status: OrderStatus): CourierOrderEvent {
  return {
    orderId: ORDER_A,
    orderNumber: 'A-1001',
    status,
    branchId,
    timestamp: new Date().toISOString(),
  };
}

describe('CouriersEventsService', () => {
  let prisma: { tenant: { findUnique: jest.Mock } };
  let service: CouriersEventsService;

  beforeEach(() => {
    prisma = { tenant: { findUnique: jest.fn().mockResolvedValue(activeTenant) } };
    service = new CouriersEventsService(prisma as never);
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

  describe('getOrderStream', () => {
    let subscription: Subscription | undefined;

    afterEach(() => {
      subscription?.unsubscribe();
      jest.useRealTimers();
    });

    it('delivers only the branch’s orders', () => {
      const received: CourierOrderEvent[] = [];
      subscription = service
        .getOrderStream(BRANCH_ID, TENANT_ID)
        .subscribe((message) => received.push(message.data as CourierOrderEvent));

      service.emitOrderEvent(makeOrderEvent(BRANCH_ID, OrderStatus.READY));
      service.emitOrderEvent(makeOrderEvent('branch-2', OrderStatus.READY));

      expect(received).toHaveLength(1);
      expect(received[0]).toMatchObject({ branchId: BRANCH_ID });
    });

    it('closes within one heartbeat of the tenant being suspended (ADR-1622 C5)', async () => {
      jest.useFakeTimers();
      let completed = false;
      subscription = service.getOrderStream(BRANCH_ID, TENANT_ID).subscribe({
        complete: () => {
          completed = true;
        },
      });

      await jest.advanceTimersByTimeAsync(KITCHEN_SSE_HEARTBEAT_MS);
      // ACTIVE at the first tick: the feed stays up.
      expect(completed).toBe(false);
      expect(prisma.tenant.findUnique).toHaveBeenCalledWith({
        where: { id: TENANT_ID },
        select: { status: true, deletedAt: true },
      });

      prisma.tenant.findUnique.mockResolvedValue({
        status: 'SUSPENDED',
        deletedAt: null,
      });
      await jest.advanceTimersByTimeAsync(KITCHEN_SSE_HEARTBEAT_MS);

      expect(completed).toBe(true);
    });

    it('closes on a tenant that is ACTIVE but soft-deleted', async () => {
      jest.useFakeTimers();
      let completed = false;
      subscription = service.getOrderStream(BRANCH_ID, TENANT_ID).subscribe({
        complete: () => {
          completed = true;
        },
      });

      prisma.tenant.findUnique.mockResolvedValue({
        status: 'ACTIVE',
        deletedAt: new Date('2026-01-01T00:00:00.000Z'),
      });
      await jest.advanceTimersByTimeAsync(KITCHEN_SSE_HEARTBEAT_MS);

      expect(completed).toBe(true);
    });

    it('closes when the tenant row is gone entirely', async () => {
      jest.useFakeTimers();
      let completed = false;
      subscription = service.getOrderStream(BRANCH_ID, TENANT_ID).subscribe({
        complete: () => {
          completed = true;
        },
      });

      // A hard-deleted tenant reads back as null — same answer, closed.
      prisma.tenant.findUnique.mockResolvedValue(null);
      await jest.advanceTimersByTimeAsync(KITCHEN_SSE_HEARTBEAT_MS);

      expect(completed).toBe(true);
    });
  });
});
