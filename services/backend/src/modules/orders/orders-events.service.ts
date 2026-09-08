import { Injectable } from '@nestjs/common';
import { Subject, Observable } from 'rxjs';
import { filter, map } from 'rxjs/operators';

export interface KdsOrderStreamEvent {
  eventType: 'ORDER_CREATED' | 'ORDER_STATUS_CHANGED';
  orderId: string;
  orderNumber: string;
  branchId: string;
  status: string;
  timestamp: string;
}

@Injectable()
export class OrdersEventsService {
  private readonly kdsEvents$ = new Subject<KdsOrderStreamEvent>();

  emitKdsEvent(event: KdsOrderStreamEvent): void {
    this.kdsEvents$.next(event);
  }

  getKdsStream(branchId: string): Observable<MessageEvent> {
    return this.kdsEvents$.asObservable().pipe(
      filter((evt) => !branchId || evt.branchId === branchId),
      map(
        (evt) =>
          ({
            data: evt,
          } as MessageEvent),
      ),
    );
  }
}
