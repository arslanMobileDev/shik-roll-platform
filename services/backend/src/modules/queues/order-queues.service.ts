import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { Queue } from 'bullmq';

export const ORDER_PROCESSING_QUEUE = 'order-processing';
export const SEND_TO_KITCHEN_JOB = 'send-to-kitchen';

export interface ProcessOrderJobData {
  orderId: string;
}

/**
 * Background processing of orders (BE-902: background work goes to BullMQ,
 * never inline in the request path). The 'order-processing' queue handles:
 * server-side totals recalculation and stop-list verification. Legacy
 * status transitions are never performed by this queue.
 */
@Injectable()
export class OrderQueuesService {
  private readonly logger = new Logger(OrderQueuesService.name);

  constructor(
    @InjectQueue(ORDER_PROCESSING_QUEUE)
    private readonly orderProcessingQueue: Queue<ProcessOrderJobData>,
  ) {}

  /**
   * Enqueue post-creation totals recalculation and stop-list checks. In the
   * default manual mode this job does not advance the kitchen status. jobId
   * is the order id, so re-creating the same order never duplicates
   * background work (idempotency, BE-907).
   */
  async scheduleOrderProcessing(orderId: string): Promise<void> {
    await this.orderProcessingQueue.add(
      'process-order',
      { orderId },
      { jobId: `process-order-${orderId}` },
    );
    this.logger.log(`Scheduled order processing for ${orderId}`);
  }

  /**
   * Notify the worker that a paid order is available. The worker records the
   * dispatch without advancing the status; the cook starts work through
   * PATCH /orders/:id/status. jobId keeps repeated webhooks idempotent.
   */
  async sendToKitchen(orderId: string): Promise<void> {
    await this.orderProcessingQueue.add(
      SEND_TO_KITCHEN_JOB,
      { orderId },
      { jobId: `send-to-kitchen:${orderId}` },
    );
    this.logger.log(`Scheduled kitchen dispatch for ${orderId}`);
  }
}
