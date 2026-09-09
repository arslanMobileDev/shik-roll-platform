import { OrderStatus } from '@prisma/client';
import { firstValueFrom, Subscription } from 'rxjs';
import { take } from 'rxjs/operators';
import {
  KitchenEventsService,
  KitchenEventBus,
} from './kitchen-events.service';
import { KITCHEN_SSE_HEARTBEAT_MS } from './kitchen.config';
import { KitchenOrderEventV1 } from './kitchen.types';

const BRANCH_ID = 'branch-1';
const ORDER_ID = '11111111-1111-1111-1111-111111111111';

function orderRecord(status: OrderStatus, overrides: Record<string, unknown> = {}) {
  return {
    id: ORDER_ID,
    branchId: BRANCH_ID,
    orderNumber: 'DEV-01-20260908-1',
    version: 5,
    status,
    type: 'DINE_IN',
    tableNumber: '7',
    comment: null,
    confirmedAt: new Date('2026-09-08T10:00:00.000Z'),
    cookingStartedAt: null,
    readyAt: null,
    createdAt: new Date('2026-09-08T09:59:00.000Z'),
    items: [],
    ...overrides,
  };
}

/** Synchronous in-memory bus double: captures publishes, replays subscribes. */
class FakeBus implements KitchenEventBus {
  published: Array<{ branchId: string; event: KitchenOrderEventV1 }> = [];
  private handlers = new Map<
    string,
    Set<(event: KitchenOrderEventV1) => void>
  >();

  publish(branchId: string, event: KitchenOrderEventV1): Promise<unknown> {
    this.published.push({ branchId, event });
    return Promise.resolve();
  }

  subscribe(
    branchId: string,
    handler: (event: KitchenOrderEventV1) => void,
  ): () => void {
    let set = this.handlers.get(branchId);
    if (!set) {
      set = new Set();
      this.handlers.set(branchId, set);
    }
    set.add(handler);
    return () => set.delete(handler);
  }

  emit(branchId: string, event: KitchenOrderEventV1): void {
    this.handlers.get(branchId)?.forEach((handler) => handler(event));
  }
}

describe('KitchenEventsService', () => {
  let prisma: { order: { findFirst: jest.Mock; findMany: jest.Mock } };
  let bus: FakeBus;
  let service: KitchenEventsService;

  beforeEach(() => {
    prisma = {
      order: { findFirst: jest.fn(), findMany: jest.fn() },
    };
    bus = new FakeBus();
    service = new KitchenEventsService(prisma as never, bus);
  });

  describe('publishOrderChanged', () => {
    it('publishes an upsert with the full board DTO while the order is on the board', async () => {
      prisma.order.findFirst.mockResolvedValue(orderRecord(OrderStatus.CONFIRMED));

      await service.publishOrderChanged(ORDER_ID);

      expect(bus.published).toHaveLength(1);
      const { branchId, event } = bus.published[0];
      expect(branchId).toBe(BRANCH_ID);
      expect(event.eventType).toBe('kitchen.order.upserted');
      expect(event.eventVersion).toBe(1);
      expect(event.orderId).toBe(ORDER_ID);
      expect(event.orderVersion).toBe(5);
      expect(event.order).toMatchObject({
        id: ORDER_ID,
        status: 'CONFIRMED',
        tableNumber: '7',
      });
    });

    it.each([OrderStatus.NEW, OrderStatus.COOKING, OrderStatus.READY] as const)(
      'publishes an upsert for %s',
      async (status) => {
        prisma.order.findFirst.mockResolvedValue(orderRecord(status));
        await service.publishOrderChanged(ORDER_ID);
        expect(bus.published[0].event.eventType).toBe('kitchen.order.upserted');
        expect(bus.published[0].event.order?.status).toBe(status);
      },
    );

    it.each([
      OrderStatus.ON_WAY,
      OrderStatus.COMPLETED,
      OrderStatus.CANCELLED,
    ] as const)('publishes a removal with a null order for %s', async (status) => {
      prisma.order.findFirst.mockResolvedValue(orderRecord(status));

      await service.publishOrderChanged(ORDER_ID);

      const { event } = bus.published[0];
      expect(event.eventType).toBe('kitchen.order.removed');
      expect(event.order).toBeNull();
      expect(event.orderId).toBe(ORDER_ID);
    });

    it('publishes nothing for a hard-deleted order', async () => {
      prisma.order.findFirst.mockResolvedValue(null);
      await service.publishOrderChanged(ORDER_ID);
      expect(bus.published).toHaveLength(0);
    });
  });

  describe('getBoardSnapshot', () => {
    it('queries only the active kitchen statuses of the branch and sorts FIFO by status entry', async () => {
      const older = orderRecord(OrderStatus.CONFIRMED, {
        id: 'older',
        confirmedAt: new Date('2026-09-08T10:00:00.000Z'),
      });
      const newer = orderRecord(OrderStatus.CONFIRMED, {
        id: 'newer',
        confirmedAt: new Date('2026-09-08T10:04:00.000Z'),
      });
      prisma.order.findMany.mockResolvedValue([newer, older]);

      const snapshot = await service.getBoardSnapshot(BRANCH_ID);

      expect(prisma.order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            branchId: BRANCH_ID,
            deletedAt: null,
            status: {
              in: [
                OrderStatus.NEW,
                OrderStatus.CONFIRMED,
                OrderStatus.COOKING,
                OrderStatus.READY,
              ],
            },
          },
        }),
      );
      expect(snapshot.orders.map((order) => order.id)).toEqual(['older', 'newer']);
      expect(Date.parse(snapshot.serverTime)).not.toBeNaN();
    });
  });

  describe('getStream', () => {
    const event: KitchenOrderEventV1 = {
      eventId: 'evt-1',
      eventType: 'kitchen.order.upserted',
      eventVersion: 1,
      occurredAt: '2026-09-08T10:05:00.000Z',
      orderId: ORDER_ID,
      orderVersion: 5,
      order: null,
    };

    it('maps branch events to typed SSE messages', async () => {
      const received: MessageEvent[] = [];
      const sub: Subscription = service
        .getStream(BRANCH_ID)
        .subscribe((message) => received.push(message));

      bus.emit(BRANCH_ID, event);
      bus.emit('branch-2', event); // foreign branch — must not leak

      expect(received).toHaveLength(1);
      expect(received[0]).toMatchObject({
        type: 'kitchen.order.upserted',
        data: event,
      });
      sub.unsubscribe();
    });

    it('stops delivering after unsubscribe', () => {
      const received: MessageEvent[] = [];
      const sub = service
        .getStream(BRANCH_ID)
        .subscribe((message) => received.push(message));
      sub.unsubscribe();

      bus.emit(BRANCH_ID, event);
      expect(received).toHaveLength(0);
    });

    it('emits heartbeats on the configured cadence', async () => {
      jest.useFakeTimers();
      try {
        const heartbeatPromise = firstValueFrom(
          service.getStream(BRANCH_ID).pipe(take(1)),
        );
        jest.advanceTimersByTime(KITCHEN_SSE_HEARTBEAT_MS);
        const heartbeat = await heartbeatPromise;
        expect(heartbeat.type).toBe('heartbeat');
        expect(
          Date.parse((heartbeat.data as { serverTime: string }).serverTime),
        ).not.toBeNaN();
      } finally {
        jest.useRealTimers();
      }
    });
  });
});
