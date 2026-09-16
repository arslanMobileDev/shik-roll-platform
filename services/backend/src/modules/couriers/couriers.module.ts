import { StaffCouriersController, CourierStaffAuthGuard } from './staff-couriers.controller';
import { Module } from '@nestjs/common';
import { CouriersController } from './couriers.controller';
import { CouriersService } from './couriers.service';
import { CouriersEventsModule } from './couriers-events.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { KitchenModule } from '../kitchen/kitchen.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';

@Module({
  imports: [PrismaModule, KitchenModule, LoyaltyModule, CouriersEventsModule],
  controllers: [CouriersController, StaffCouriersController],
  providers: [CouriersService, CourierStaffAuthGuard],
  exports: [CouriersService, CouriersEventsModule],
})
export class CouriersModule {}
