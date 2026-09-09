import { randomUUID } from 'node:crypto';
import {
  Inject,
  Injectable,
  Logger,
  OnModuleDestroy,
  Provider,
} from '@nestjs/common';
import { OrderStatus } from '@prisma/client';
import Redis from 'ioredis';
import { interval, merge, Observable, Subject } from 'rxjs';
import { filter, map } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';
import { ORDER_INCLUDE } from '../orders/mappers/order.mapper';
import { buildRedisConnection } from '../queues/queues.module';
import {
  KITCHEN_CHANNEL_PREFIX,
  KITCHEN_SSE_HEARTBEAT_MS,
} from './kitchen.config';
import { compareByStatusEntry, toKitchenOrder } from './kitchen.mapper';
import {
  KITCHEN_ACTIVE_STATUSES,
  KitchenBoardSnapshotDto,
  KitchenOrderEventV1,
} from './kitchen.types';

/**
 * Branch fan-out transport for kitchen events (ADR-1618): Redis Pub/Sub when
 * Redis is configured (production, multi-instance), an in-process Subject
 * otherwise (unit tests, DISABLE_QUEUES e2e, local dev without Redis).
 * Pub/Sub is realtime fan-out only — never a durable event bus; PostgreSQL
 * stays the source of truth.
 */
export interface KitchenEventBus {
  publish(branchId: string, event: KitchenOrderEventV1): Promise<unknown>;
  /** Subscribe to one branch channel; returns the unsubscribe callback. */
  subscribe(
    branchId: string,
    handler: (event: KitchenOrderEventV1) => void,
  ): () => void;
}

export const KITCHEN_EVENT_BUS = Symbol('KITCHEN_EVENT_BUS');

function redisConfigured(): boolean {
  return Boolean(process.env.REDIS_URL || process.env.REDIS_HOST);
}

/** In-process bus: no external broker, events live and die in this instance. */
class InMemoryKitchenEventBus implements KitchenEventBus {
  private readonly events$ = new Subject<{
    branchId: string;
    event: KitchenOrderEventV1;
  }>();

  publish(branchId: string, event: KitchenOrderEventV1): Promise<unknown> {
    this.events$.next({ branchId, event });
    return Promise.resolve();
  }

  subscribe(
    branchId: string,
    handler: (event: KitchenOrderEventV1) => void,
  ): () => void {
    const subscription = this.events$
      .pipe(filter((entry) => entry.branchId === branchId))
      .subscribe((entry) => handler(entry.event));
    return () => subscription.unsubscribe();
  }
}

/**
 * Redis Pub/Sub bus on the `kitchen.branch.{branchId}` channels. Pub/Sub
 * needs a dedicated subscriber connection (a subscribed client cannot run
 * regular commands), so the bus holds two connections. Channel subscriptions
 * are reference-counted: the Redis channel is dropped when the last local
 * subscriber of the branch goes away.
 */
class RedisKitchenEventBus implements KitchenEventBus, OnModuleDestroy {
  private readonly logger = new Logger(RedisKitchenEventBus.name);
  private readonly publisher: Redis;
  private readonly subscriber: Redis;
  private readonly handlers = new Map<
    string,
    Set<(event: KitchenOrderEventV1) => void>
  >();

  constructor() {
    const connection = buildRedisConnection();
    this.publisher = new Redis(connection);
    this.subscriber = new Redis(connection);
    this.subscriber.on('message', (channel: string, message: string) => {
      const branchId = channel.slice(KITCHEN_CHANNEL_PREFIX.length);
      const handlers = this.handlers.get(branchId);
      if (!handlers || handlers.size === 0) return;
      let event: KitchenOrderEventV1;
      try {
        event = JSON.parse(message) as KitchenOrderEventV1;
      } catch {
        this.logger.warn(`Dropping undecodable kitchen event on ${channel}`);
        return;
      }
      for (const handler of handlers) handler(event);
    });
  }

  publish(branchId: string, event: KitchenOrderEventV1): Promise<unknown> {
    return this.publisher.publish(
      KITCHEN_CHANNEL_PREFIX + branchId,
      JSON.stringify(event),
    );
  }

  subscribe(
    branchId: string,
    handler: (event: KitchenOrderEventV1) => void,
  ): () => void {
    const channel = KITCHEN_CHANNEL_PREFIX + branchId;
    let handlers = this.handlers.get(branchId);
    if (!handlers) {
      handlers = new Set();
      this.handlers.set(branchId, handlers);
      void this.subscriber.subscribe(channel);
    }
    handlers.add(handler);
    return () => {
      const current = this.handlers.get(branchId);
      if (!current) return;
      current.delete(handler);
      if (current.size === 0) {
        this.handlers.delete(branchId);
        void this.subscriber.unsubscribe(channel);
      }
    };
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.allSettled([this.publisher.quit(), this.subscriber.quit()]);
  }
}

export const kitchenEventBusProvider: Provider = {
  provide: KITCHEN_EVENT_BUS,
  useFactory: (): KitchenEventBus =>
    redisConfigured() ? new RedisKitchenEventBus() : new InMemoryKitchenEventBus(),
};

@Injectable()
export class KitchenEventsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(KITCHEN_EVENT_BUS) private readonly bus: KitchenEventBus,
  ) {}

  /**
   * Publish the committed board state of an order to its branch channel
   * (ADR-1618): an upsert event while the order is on the board
   * (NEW/CONFIRMED/COOKING/READY), a removed event once it leaves (ON_WAY,
   * COMPLETED, CANCELLED, ...). The published state is re-read from
   * PostgreSQL after the caller's commit — the DB snapshot stays the source
   * of truth, and clients deduplicate by `orderVersion` anyway.
   */
  async publishOrderChanged(orderId: string): Promise<void> {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
      include: ORDER_INCLUDE,
    });
    if (!order) return; // Hard-deleted: nothing reliable to publish.

    const onBoard = (KITCHEN_ACTIVE_STATUSES as readonly OrderStatus[]).includes(
      order.status,
    );
    const event: KitchenOrderEventV1 = {
      eventId: randomUUID(),
      eventType: onBoard ? 'kitchen.order.upserted' : 'kitchen.order.removed',
      eventVersion: 1,
      occurredAt: new Date().toISOString(),
      orderId: order.id,
      orderVersion: order.version,
      order: onBoard ? toKitchenOrder(order) : null,
    };
    await this.bus.publish(order.branchId, event);
  }

  /** Branch-scoped board snapshot (the payload of GET /kitchen/orders/active). */
  async getBoardSnapshot(branchId: string): Promise<KitchenBoardSnapshotDto> {
    const orders = await this.prisma.order.findMany({
      where: {
        branchId,
        deletedAt: null,
        status: { in: [...KITCHEN_ACTIVE_STATUSES] },
      },
      include: ORDER_INCLUDE,
    });
    return {
      serverTime: new Date().toISOString(),
      orders: orders.map(toKitchenOrder).sort(compareByStatusEntry),
    };
  }

  /**
   * Branch-scoped SSE stream (ADR-1618): live upsert/remove events plus a
   * heartbeat well under the 20 s contract so proxies keep the connection
   * and clients can detect a silent drop.
   */
  getStream(branchId: string): Observable<MessageEvent> {
    const events$ = new Observable<KitchenOrderEventV1>((subscriber) => {
      const unsubscribe = this.bus.subscribe(branchId, (event) =>
        subscriber.next(event),
      );
      return () => unsubscribe();
    }).pipe(
      map(
        (event) =>
          ({
            type: event.eventType,
            data: event,
          }) as MessageEvent,
      ),
    );
    const heartbeat$ = interval(KITCHEN_SSE_HEARTBEAT_MS).pipe(
      map(
        () =>
          ({
            type: 'heartbeat',
            data: { serverTime: new Date().toISOString() },
          }) as MessageEvent,
      ),
    );
    return merge(events$, heartbeat$);
  }
}
