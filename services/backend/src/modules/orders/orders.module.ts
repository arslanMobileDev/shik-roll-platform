import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { OrdersRepository } from './orders.repository';
import { OrdersEventsService } from './orders-events.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { CouriersModule } from '../couriers/couriers.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';

@Module({
  imports: [PrismaModule, CouriersModule, LoyaltyModule],
  controllers: [OrdersController],
  providers: [OrdersService, OrdersRepository, OrdersEventsService],
  exports: [OrdersService, OrdersRepository, OrdersEventsService],
})
export class OrdersModule {}
