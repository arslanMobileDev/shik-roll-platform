import { BullModule, getQueueToken } from '@nestjs/bullmq';
import { Global, Logger, Module } from '@nestjs/common';
import { KitchenModule } from '../kitchen/kitchen.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import {
  CUSTOMER_MAINTENANCE_QUEUE,
  CustomerMaintenanceProcessor,
} from './customer-maintenance.processor';
import { OrderProcessingProcessor } from './order-processing.processor';
import { OrderQueuesService, ORDER_PROCESSING_QUEUE } from './order-queues.service';

/**
 * BullMQ over Redis (ADR-1605 stack: BullMQ for background jobs).
 * Connection is configured once here; queues register per bounded context.
 * Redis connection: REDIS_URL (redis://host:port) with REDIS_HOST/REDIS_PORT
 * fallback for local development.
 */
export function buildRedisConnection(): {
  host: string;
  port: number;
  password?: string;
} {
  const url = process.env.REDIS_URL;
  if (url) {
    const parsed = new URL(url);
    return {
      host: parsed.hostname,
      port: Number(parsed.port || 6379),
      ...(parsed.password ? { password: parsed.password } : {}),
    };
  }
  return {
    host: process.env.REDIS_HOST ?? 'localhost',
    port: Number(process.env.REDIS_PORT ?? 6379),
  };
}

export function queuesDisabled(): boolean {
  return process.env.DISABLE_QUEUES === 'true';
}

@Global()
@Module({})
export class QueuesModule {
  static register() {
    const disabled = queuesDisabled();

    return {
      module: QueuesModule,
      // LoyaltyModule backs the worker's cashback/refund hooks (ADR-1614);
      // KitchenModule the board fan-out of worker-driven transitions (ADR-1618).
      imports: disabled
        ? [LoyaltyModule, KitchenModule]
        : [
            LoyaltyModule,
            KitchenModule,
            BullModule.forRoot({
              connection: buildRedisConnection(),
              defaultJobOptions: {
                // Retry strategy: 3 attempts, exponential backoff from 1s.
                attempts: 3,
                backoff: { type: 'exponential', delay: 1000 },
                removeOnComplete: { count: 1000 },
                removeOnFail: { count: 5000 },
              },
            }),
            BullModule.registerQueue({ name: ORDER_PROCESSING_QUEUE }),
            BullModule.registerQueue({ name: CUSTOMER_MAINTENANCE_QUEUE }),
          ],
      providers: disabled
        ? [
            OrderQueuesService,
            {
              provide: getQueueToken(ORDER_PROCESSING_QUEUE),
              useValue: {
                add: async (...args: unknown[]) => {
                  Logger.log(
                    `Queues disabled, job dropped: ${String(args[0])}`,
                    'QueuesModule',
                  );
                  return { id: 'disabled' };
                },
              },
            },
            {
              // The maintenance processor is not registered when queues are
              // off, so nothing injects this — it exists only so the module
              // graph matches the enabled branch.
              provide: getQueueToken(CUSTOMER_MAINTENANCE_QUEUE),
              useValue: {
                upsertJobScheduler: async () => ({ id: 'disabled' }),
              },
            },
          ]
        : [OrderQueuesService, OrderProcessingProcessor, CustomerMaintenanceProcessor],
      exports: disabled
        ? [OrderQueuesService, getQueueToken(ORDER_PROCESSING_QUEUE)]
        : [BullModule, OrderQueuesService],
    };
  }
}
