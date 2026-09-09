import { Module } from '@nestjs/common';
import { OrdersEventsService } from './orders-events.service';

@Module({
  providers: [OrdersEventsService],
  exports: [OrdersEventsService],
})
export class OrdersEventsModule {}
