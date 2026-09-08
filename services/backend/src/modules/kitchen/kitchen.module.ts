import { Module, OnModuleInit } from '@nestjs/common';
import { KitchenController } from './kitchen.controller';
import { KitchenService } from './kitchen.service';
import {
  KitchenEventsService,
  kitchenEventBusProvider,
} from './kitchen-events.service';
import { assertKitchenConfig } from './kitchen.config';

/**
 * Kitchen bounded context (ADR-1618): terminal PIN auth, branch board
 * snapshot, kitchen-owned status transitions and the SSE fan-out. Prisma and
 * JwtModule are global (PrismaModule / AuthModule); the event bus factory
 * picks Redis Pub/Sub when Redis is configured, in-process otherwise.
 *
 * KitchenEventsService is exported so the orders/payments/queues contexts
 * can publish board changes (order enters CONFIRMED, leaves the board, ...).
 */
@Module({
  controllers: [KitchenController],
  providers: [KitchenService, KitchenEventsService, kitchenEventBusProvider],
  exports: [KitchenEventsService],
})
export class KitchenModule implements OnModuleInit {
  /** ADR-1618: status emulation in production is a configuration error — stop the boot. */
  onModuleInit(): void {
    assertKitchenConfig();
  }
}
