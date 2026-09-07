import { Injectable } from '@nestjs/common';
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

@Injectable()
export class CouriersEventsService {
  private readonly events$ = new Subject<CourierOrderEvent>();

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
}
