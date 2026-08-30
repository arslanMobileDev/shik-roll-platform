import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { MenuModule } from './modules/menu/menu.module';
import { OrdersModule } from './modules/orders/orders.module';
import { QueuesModule } from './modules/queues/queues.module';

@Module({
  imports: [PrismaModule, QueuesModule.register(), MenuModule, OrdersModule],
})
export class AppModule {}
