import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { StaffOrdersController } from './staff-orders.controller';
import { OrdersService } from './orders.service';
import { OrdersRepository } from './orders.repository';
import { PrismaModule } from '../../prisma/prisma.module';
import { CouriersModule } from '../couriers/couriers.module';
import { GeoModule } from '../geo/geo.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { PaymentsModule } from '../payments/payments.module';
import { KitchenModule } from '../kitchen/kitchen.module';
import { StaffModule } from '../staff/staff.module';

@Module({
  imports: [
    PrismaModule,
    GeoModule,
    CouriersModule,
    LoyaltyModule,
    KitchenModule,
    PaymentsModule,
    StaffModule,
  ],
  controllers: [OrdersController, StaffOrdersController],
  providers: [OrdersService, OrdersRepository],
  exports: [OrdersService, OrdersRepository],
})
export class OrdersModule {}
