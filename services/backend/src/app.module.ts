import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { MenuModule } from './modules/menu/menu.module';
import { OrdersModule } from './modules/orders/orders.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { QueuesModule } from './modules/queues/queues.module';
import { CouriersModule } from './modules/couriers/couriers.module';
import { KitchenModule } from './modules/kitchen/kitchen.module';
import { LoyaltyModule } from './modules/loyalty/loyalty.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { HealthController } from './health.controller';

@Module({
  imports: [
    PrismaModule,
    QueuesModule.register(),
    AuthModule,
    MenuModule,
    OrdersModule,
    PaymentsModule,
    CouriersModule,
    KitchenModule,
    LoyaltyModule,
    UploadsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
