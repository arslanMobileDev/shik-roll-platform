import { Injectable } from '@nestjs/common';
import { OrderStatus } from '@prisma/client';
import { Subject, Observable } from 'rxjs';
import { filter, map, takeUntil } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';
import { KITCHEN_SSE_HEARTBEAT_MS } from '../kitchen/kitchen.config';
import { tenantActiveGuard$ } from '../tenant/tenant-stream-guard';

export interface CourierOrderEvent {
  orderId: string;
  orderNumber: string;
  status: string;
  branchId: string;
  courierId?: string | null;
  deliveryAddress?: string | null;
  totalRubles?: number;
  timestamp: string;
}

/**
 * Customer-facing order tracking event (ADR-1615). Carries the canonical
 * backend OrderStatus plus the fields the client needs to render the
 * timeline and deduplicate by version.
 */
export interface OrderTrackingEvent {
  orderId: string;
  status: OrderStatus;
  courierId: string | null;
  version: number;
  estimatedReadyAt: string | null;
  timestamp: string;
}

/**
 * Accepted courier location fix (ADR-1617). Published in-memory only —
 * persistence/retention for dispatch maps is a separate data-retention
 * decision; raw coordinates are never logged.
 */
export interface CourierLocationEvent {
  orderId: string;
  courierId: string;
  branchId: string;
  latitude: number;
  longitude: number;
  accuracyMeters: number;
  capturedAt: string;
}

@Injectable()
export class CouriersEventsService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly events$ = new Subject<CourierOrderEvent>();
  private readonly trackingEvents$ = new Subject<OrderTrackingEvent>();
  private readonly locationEvents$ = new Subject<CourierLocationEvent>();

  emitOrderEvent(event: CourierOrderEvent) {
    this.events$.next(event);
  }

  /** Publish an accepted courier location fix (branch-scoped consumers). */
  emitCourierLocation(event: CourierLocationEvent) {
    this.locationEvents$.next(event);
  }

  /** Live courier fixes of one branch (dispatcher map, future consumers). */
  getCourierLocationStream(branchId: string): Observable<CourierLocationEvent> {
    return this.locationEvents$
      .asObservable()
      .pipe(filter((evt) => evt.branchId === branchId));
  }

  /**
   * Branch-scoped courier feed. `branchId` is required — a stream without a
   * branch would fan every branch's orders out to one courier.
   *
   * Like the kitchen board (ADR-1622 C5), the stream ends on its own when the
   * courier's tenant leaves ACTIVE: the guard reads the tenant row on the
   * kitchen heartbeat cadence, the only SSE cadence the platform has, and
   * completes the flow. The client reconnects and the guard answers 403.
   */
  getOrderStream(branchId: string, tenantId: string): Observable<MessageEvent> {
    return this.events$.asObservable().pipe(
      filter((evt) => evt.branchId === branchId),
      map(
        (evt) =>
          ({
            data: evt,
          } as MessageEvent),
      ),
      takeUntil(
        tenantActiveGuard$(this.prisma, tenantId, KITCHEN_SSE_HEARTBEAT_MS),
      ),
    );
  }

  /** Publish a status change to the subscribers of this specific order. */
  emitOrderTrackingEvent(event: OrderTrackingEvent) {
    this.trackingEvents$.next(event);
  }

  /** Live stream of tracking events for one order (customer tracking, ADR-1615). */
  getOrderTrackingStream(orderId: string): Observable<MessageEvent> {
    return this.trackingEvents$.asObservable().pipe(
      filter((evt) => evt.orderId === orderId),
      map(
        (evt) =>
          ({
            data: evt,
          } as MessageEvent),
      ),
    );
  }
}
