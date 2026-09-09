import { InjectQueue, OnWorkerEvent, Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger, Optional } from '@nestjs/common';
import { OrderStatus, Prisma } from '@prisma/client';
import { Job, Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { lineTotal, orderSubtotal, orderTotal } from '../orders/domain/order-pricing';
import { canTransition } from '../orders/domain/order-status-machine';
import { KitchenEventsService } from '../kitchen/kitchen-events.service';
import {
  ORDER_PROCESSING_QUEUE,
  ProcessOrderJobData,
  SEND_TO_KITCHEN_JOB,
} from './order-queues.service';

const STATUS_TIMER_JOB = 'status-timer';

/**
 * Legacy development automation is opt-in. Kitchen order statuses are manual
 * by default and are changed through PATCH /orders/:id/status.
 */
export function automaticOrderStatusTransitionsEnabled(): boolean {
  return process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED === 'true';
}

export interface StatusTimerJobData {
  orderId: string;
  to: OrderStatus;
}

/**
 * Timer emulation for the order lifecycle (dev harness): after background
 * processing confirms an order, COOKING and READY follow on delays.
 * Overridable via env for tests/dev.
 */
const STATUS_TIMER_DELAYS_MS: ReadonlyArray<{ to: OrderStatus; delayMs: number }> = [
  { to: OrderStatus.COOKING, delayMs: Number(process.env.ORDER_TIMER_COOKING_MS ?? 30_000) },
  { to: OrderStatus.READY, delayMs: Number(process.env.ORDER_TIMER_READY_MS ?? 90_000) },
];

/**
 * 'order-processing' worker: server-side totals recalculation, stop-list
 * verification and emulated status timers. Retry strategy comes from the
 * queue defaults (3 attempts, exponential backoff from 1s) — BullMQ re-runs
 * the job on throw, and the failed handler logs terminal failures.
 */
@Injectable()
@Processor(ORDER_PROCESSING_QUEUE)
export class OrderProcessingProcessor extends WorkerHost {
  private readonly logger = new Logger(OrderProcessingProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly loyalty: LoyaltyService,
    @InjectQueue(ORDER_PROCESSING_QUEUE)
    private readonly queue: Queue<ProcessOrderJobData | StatusTimerJobData>,
    @Optional() private readonly kitchenEvents?: KitchenEventsService,
  ) {
    super();
  }

  async process(job: Job<ProcessOrderJobData | StatusTimerJobData>): Promise<void> {
    switch (job.name) {
      case 'process-order':
        await this.processOrder(job as Job<ProcessOrderJobData>);
        return;
      case SEND_TO_KITCHEN_JOB:
        await this.sendToKitchen(job as Job<ProcessOrderJobData>);
        return;
      case STATUS_TIMER_JOB:
        await this.advanceStatus(job as Job<StatusTimerJobData>);
        return;
      default:
        this.logger.warn(`Unknown job name: ${job.name}`);
    }
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, error: Error): void {
    const terminal = job.attemptsMade >= (job.opts.attempts ?? 1);
    this.logger.error(
      `Job ${job.name} (${job.id}) failed at attempt ${job.attemptsMade}` +
        `${terminal ? ' — attempts exhausted' : ', will retry'}: ${error.message}`,
      error.stack,
    );
  }

  private async processOrder(job: Job<ProcessOrderJobData>): Promise<void> {
    const { orderId } = job.data;
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
      include: { items: { include: { modifiers: true } } },
    });
    if (!order) {
      // Nothing to retry against — a missing order is terminal, not transient.
      this.logger.warn(`process-order: order ${orderId} not found, skipping`);
      return;
    }

    // 1. Stop-list check: cancel the order if any line is stop-listed at the branch.
    const stopListed = await this.prisma.stopListEntry.findMany({
      where: {
        branchId: order.branchId,
        menuItemId: { in: order.items.map((item) => item.menuItemId) },
        isActive: true,
        startsAt: { lte: new Date() },
        OR: [{ endsAt: null }, { endsAt: { gt: new Date() } }],
      },
      select: { menuItemId: true },
    });
    if (stopListed.length > 0) {
      this.logger.warn(
        `process-order: order ${orderId} contains stop-listed items ` +
          `(${stopListed.map((s) => s.menuItemId).join(', ')}), cancelling`,
      );
      await this.transitionWithHistory(orderId, order.status, OrderStatus.CANCELLED, {
        reason: 'STOP_LISTED',
      });
      return;
    }

    // 2. Server-side totals recalculation (BE-907: never trust client prices).
    const pricedItems = order.items.map((item) => ({
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      modifiers: item.modifiers.map((modifier) => ({
        priceDelta: modifier.priceDelta,
        quantity: modifier.quantity,
      })),
    }));
    const subtotal = orderSubtotal(pricedItems);
    // The payable total keeps the checkout bonus discount (ADR-1614):
    // recalculation must never give back the points already spent.
    const total = orderTotal(subtotal.minus(order.bonusDiscountAmount));

    await this.prisma.$transaction([
      ...order.items.map((item, index) =>
        this.prisma.orderItem.update({
          where: { id: item.id },
          data: { totalAmount: lineTotal(pricedItems[index]) },
        }),
      ),
      this.prisma.order.update({
        where: { id: orderId },
        data: { subtotalAmount: subtotal, totalAmount: total },
      }),
    ]);

    // 3. Legacy dev harness only: confirm and schedule lifecycle timers.
    // Production/default mode leaves kitchen status changes to the cook.
    if (!automaticOrderStatusTransitionsEnabled()) {
      this.logger.log(`process-order: manual status mode for order ${orderId}`);
      return;
    }

    if (order.status === OrderStatus.NEW) {
      await this.transitionWithHistory(orderId, OrderStatus.NEW, OrderStatus.CONFIRMED, {
        reason: 'AUTO_CONFIRM',
      });
      for (const step of STATUS_TIMER_DELAYS_MS) {
        await this.queue.add(
          STATUS_TIMER_JOB,
          { orderId, to: step.to },
          { delay: step.delayMs, jobId: `status-timer:${orderId}:${step.to}` },
        );
      }
    }
  }

  /**
   * Kitchen dispatch for a paid order (payments contract): CONFIRMED ->
   * COOKING, guarded by the state machine so a duplicate or late job
   * (order already cooking, cancelled, ...) is a logged no-op.
   */
  private async sendToKitchen(job: Job<ProcessOrderJobData>): Promise<void> {
    const { orderId } = job.data;
    if (!automaticOrderStatusTransitionsEnabled()) {
      this.logger.log(`send-to-kitchen: manual status mode for order ${orderId}`);
      return;
    }

    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
      select: { status: true },
    });
    if (!order) {
      this.logger.warn(`send-to-kitchen: order ${orderId} not found, skipping`);
      return;
    }
    if (!canTransition(order.status, OrderStatus.COOKING)) {
      this.logger.log(
        `send-to-kitchen: skipping ${order.status} -> COOKING for order ${orderId} (not allowed)`,
      );
      return;
    }
    await this.transitionWithHistory(orderId, order.status, OrderStatus.COOKING, {
      reason: 'PAID_ONLINE',
    });
  }

  private async advanceStatus(job: Job<StatusTimerJobData>): Promise<void> {
    const { orderId, to } = job.data;
    if (!automaticOrderStatusTransitionsEnabled()) {
      this.logger.log(`status-timer: manual status mode for order ${orderId}`);
      return;
    }

    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
      select: { status: true },
    });
    if (!order) {
      this.logger.warn(`status-timer: order ${orderId} not found, skipping`);
      return;
    }
    // Timer emulation must never break the state machine: skip transitions
    // that no longer apply (e.g. the operator already moved or cancelled).
    if (!canTransition(order.status, to)) {
      this.logger.log(
        `status-timer: skipping ${order.status} -> ${to} for order ${orderId} (not allowed)`,
      );
      return;
    }
    await this.transitionWithHistory(orderId, order.status, to, { reason: 'AUTO_TIMER' });
  }

  private async transitionWithHistory(
    orderId: string,
    from: OrderStatus,
    to: OrderStatus,
    options: { reason?: string },
  ): Promise<void> {
    const terminalPatch: Prisma.OrderUncheckedUpdateInput = {};
    if (to === OrderStatus.COMPLETED) terminalPatch.completedAt = new Date();
    if (to === OrderStatus.CANCELLED) {
      terminalPatch.cancelledAt = new Date();
      terminalPatch.cancelReason = options.reason ?? null;
    }
    await this.prisma.$transaction([
      this.prisma.order.update({
        where: { id: orderId },
        data: { status: to, ...terminalPatch, version: { increment: 1 } },
      }),
      this.prisma.orderStatusHistory.create({
        data: {
          orderId,
          previousStatus: from,
          newStatus: to,
          reason: options.reason ?? null,
        },
      }),
    ]);
    this.logger.log(`Order ${orderId}: ${from} -> ${to} (${options.reason ?? 'n/a'})`);
    await this.kitchenEvents?.publishOrderChanged(orderId);

    // Loyalty (ADR-1614): a worker-driven terminal transition follows the same
    // rules as the operator path — COMPLETED accrues cashback, CANCELLED
    // (e.g. stop-listed checkout) refunds the spent points. Idempotent.
    if (to === OrderStatus.COMPLETED) {
      await this.loyalty.earnCashback(orderId);
    } else if (to === OrderStatus.CANCELLED) {
      await this.loyalty.refundOnCancel(orderId);
    }
  }
}
