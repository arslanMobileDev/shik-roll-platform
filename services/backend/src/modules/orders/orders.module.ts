import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { OrdersRepository } from './orders.repository';
import { PrismaModule } from '../../prisma/prisma.module';
import { CouriersModule } from '../couriers/couriers.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { PaymentsModule } from '../payments/payments.module';
import { OrdersEventsModule } from './orders-events.module';

@Module({
  imports: [
    PrismaModule,
    CouriersModule,
    LoyaltyModule,
    OrdersEventsModule,
    PaymentsModule,
  ],
  controllers: [OrdersController],
  providers: [OrdersService, OrdersRepository],
  exports: [OrdersService, OrdersRepository, OrdersEventsModule],
})
export class OrdersModule {}
