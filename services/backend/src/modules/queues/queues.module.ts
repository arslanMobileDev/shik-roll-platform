import { BullModule, getQueueToken } from '@nestjs/bullmq';
import { Global, Logger, Module } from '@nestjs/common';
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
      imports: disabled
        ? []
        : [
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
          ]
        : [OrderQueuesService, OrderProcessingProcessor],
      exports: disabled
        ? [OrderQueuesService, getQueueToken(ORDER_PROCESSING_QUEUE)]
        : [BullModule, OrderQueuesService],
    };
  }
}
