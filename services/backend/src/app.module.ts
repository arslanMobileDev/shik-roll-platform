import { CooksModule } from './modules/cooks/cooks.module';
import { AnalyticsModule } from './modules/staff-analytics/analytics.module';
import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { TenantMiddleware } from './modules/tenant/tenant.middleware';
import { AuthModule } from './modules/auth/auth.module';
import { MenuModule } from './modules/menu/menu.module';
import { OrdersModule } from './modules/orders/orders.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { QueuesModule } from './modules/queues/queues.module';
import { CouriersModule } from './modules/couriers/couriers.module';
import { KitchenModule } from './modules/kitchen/kitchen.module';
import { GeoModule } from './modules/geo/geo.module';
import { LoyaltyModule } from './modules/loyalty/loyalty.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { StaffModule } from './modules/staff/staff.module';
import { HealthController } from './health.controller';
import { RestaurantsController } from './restaurants.controller';

@Module({
  imports: [
    CooksModule,
    PrismaModule,
    QueuesModule.register(),
    AuthModule,
    MenuModule,
    OrdersModule,
    PaymentsModule,
    CouriersModule,
    KitchenModule,
    LoyaltyModule,
    GeoModule,
    UploadsModule,
    StaffModule,
    AnalyticsModule,
  ],
  controllers: [HealthController, RestaurantsController],
})
export class AppModule implements NestModule {
  /**
   * Applied to every route rather than to the three PIN login routes: with no
   * X-Tenant header the middleware costs one property check, and the catalog
   * isolation step (ADR-1622, holes H1/H2) needs it globally anyway.
   *
   * '{*splat}' is the Nest 11 spelling — path-to-regexp v8 rejects a bare '*'.
   */
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(TenantMiddleware).forRoutes('{*splat}');
  }
}
