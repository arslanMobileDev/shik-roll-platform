import { InjectQueue, OnWorkerEvent, Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { OrderStatus, Prisma } from '@prisma/client';
import { Job, Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { lineTotal, orderSubtotal, orderTotal } from '../orders/domain/order-pricing';
import { canTransition } from '../orders/domain/order-status-machine';
import { ORDER_PROCESSING_QUEUE, ProcessOrderJobData } from './order-queues.service';

const STATUS_TIMER_JOB = 'status-timer';

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
    @InjectQueue(ORDER_PROCESSING_QUEUE)
    private readonly queue: Queue<ProcessOrderJobData | StatusTimerJobData>,
  ) {
    super();
  }

  async process(job: Job<ProcessOrderJobData | StatusTimerJobData>): Promise<void> {
    switch (job.name) {
      case 'process-order':
        await this.processOrder(job as Job<ProcessOrderJobData>);
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
    const total = orderTotal(subtotal);

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

    // 3. Confirm the order and schedule the emulated lifecycle timers.
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

  private async advanceStatus(job: Job<StatusTimerJobData>): Promise<void> {
    const { orderId, to } = job.data;
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
  }
}
