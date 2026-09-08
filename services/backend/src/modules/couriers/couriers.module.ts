import { Module } from '@nestjs/common';
import { CouriersController } from './couriers.controller';
import { CouriersService } from './couriers.service';
import { CouriersEventsService } from './couriers-events.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { KitchenModule } from '../kitchen/kitchen.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';

@Module({
  imports: [PrismaModule, KitchenModule, LoyaltyModule],
  controllers: [CouriersController],
  providers: [CouriersService, CouriersEventsService],
  exports: [CouriersService, CouriersEventsService],
})
export class CouriersModule {}
