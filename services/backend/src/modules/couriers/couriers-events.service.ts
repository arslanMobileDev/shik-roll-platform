import { Injectable } from '@nestjs/common';
import { OrderStatus } from '@prisma/client';
import { Subject, Observable } from 'rxjs';
import { filter, map } from 'rxjs/operators';

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

@Injectable()
export class CouriersEventsService {
  private readonly events$ = new Subject<CourierOrderEvent>();
  private readonly trackingEvents$ = new Subject<OrderTrackingEvent>();

  emitOrderEvent(event: CourierOrderEvent) {
    this.events$.next(event);
  }

  getOrderStream(branchId?: string): Observable<MessageEvent> {
    return this.events$.asObservable().pipe(
      filter((evt) => !branchId || evt.branchId === branchId),
      map(
        (evt) =>
          ({
            data: evt,
          } as MessageEvent),
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
