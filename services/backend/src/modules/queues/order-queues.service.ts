import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { Queue } from 'bullmq';

export const ORDER_PROCESSING_QUEUE = 'order-processing';

export interface ProcessOrderJobData {
  orderId: string;
}

/**
 * Background processing of orders (BE-902: background work goes to BullMQ,
 * never inline in the request path). The 'order-processing' queue handles:
 * server-side totals recalculation, stop-list verification and the emulated
 * status timers that advance an order through its lifecycle.
 */
@Injectable()
export class OrderQueuesService {
  private readonly logger = new Logger(OrderQueuesService.name);

  constructor(
    @InjectQueue(ORDER_PROCESSING_QUEUE)
    private readonly orderProcessingQueue: Queue<ProcessOrderJobData>,
  ) {}

  /**
   * Enqueue post-creation processing: totals recalculation, stop-list check,
   * then schedule the emulated lifecycle timers (NEW -> CONFIRMED -> COOKING
   * -> READY). jobId is the order id, so re-creating the same order never
   * duplicates background work (idempotency, BE-907).
   */
  async scheduleOrderProcessing(orderId: string): Promise<void> {
    await this.orderProcessingQueue.add(
      'process-order',
      { orderId },
      { jobId: `process-order:${orderId}` },
    );
    this.logger.log(`Scheduled order processing for ${orderId}`);
  }
}
