import { InjectQueue, OnWorkerEvent, Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable, Logger, Optional } from '@nestjs/common';
import { OrderStatus, Prisma } from '@prisma/client';
import { Job, Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { kdsStatusEmulationEnabled } from '../kitchen/kitchen.config';
import { KitchenEventsService } from '../kitchen/kitchen-events.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { lineTotal, orderSubtotal, orderTotal } from '../orders/domain/order-pricing';
import { canTransition } from '../orders/domain/order-status-machine';
import {
  ORDER_PROCESSING_QUEUE,
  ProcessOrderJobData,
  SEND_TO_KITCHEN_JOB,
} from './order-queues.service';

const STATUS_TIMER_JOB = 'status-timer';

export interface StatusTimerJobData {
  orderId: string;
  to: OrderStatus;
}

/**
 * Timer emulation for the order lifecycle (dev harness only, ADR-1618): after
 * background processing confirms an order, COOKING and READY follow on
 * delays — but ONLY when KDS_STATUS_EMULATION_ENABLED=true outside
 * production. In production the kitchen terminal owns those transitions.
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
    // Optional so unit specs can construct the processor without the kitchen
    // bounded context; always present in the wired app.
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

    // 3. Confirm the order. Production flow ENDS at CONFIRMED (ADR-1618):
    // the kitchen terminal owns COOKING/READY; the emulated lifecycle timers
    // are scheduled only by the dev-harness flag.
    if (order.status === OrderStatus.NEW) {
      await this.transitionWithHistory(orderId, OrderStatus.NEW, OrderStatus.CONFIRMED, {
        reason: 'AUTO_CONFIRM',
      });
      if (kdsStatusEmulationEnabled()) {
        for (const step of STATUS_TIMER_DELAYS_MS) {
          await this.queue.add(
            STATUS_TIMER_JOB,
            { orderId, to: step.to },
            { delay: step.delayMs, jobId: `status-timer:${orderId}:${step.to}` },
          );
        }
      }
    }
  }

  /**
   * Kitchen dispatch for a paid order — DEV EMULATION ONLY (ADR-1618). In
   * production the payment flow ends at CONFIRMED and the kitchen terminal
   * starts cooking; with the emulation flag off this job is a logged no-op.
   * When enabled, CONFIRMED -> COOKING is guarded by the state machine so a
   * duplicate or late job is a no-op as well.
   */
  private async sendToKitchen(job: Job<ProcessOrderJobData>): Promise<void> {
    const { orderId } = job.data;
    if (!kdsStatusEmulationEnabled()) {
      this.logger.log(
        `send-to-kitchen: emulation disabled, skipping auto COOKING for order ${orderId} (ADR-1618)`,
      );
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
    if (!kdsStatusEmulationEnabled()) {
      this.logger.log(
        `status-timer: emulation disabled, skipping auto ${to} for order ${orderId} (ADR-1618)`,
      );
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
    // Kitchen POS (ADR-1618): server-side timestamps for the board timers.
    if (to === OrderStatus.CONFIRMED) terminalPatch.confirmedAt = new Date();
    if (to === OrderStatus.COOKING) terminalPatch.cookingStartedAt = new Date();
    if (to === OrderStatus.READY) terminalPatch.readyAt = new Date();
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

    // Kitchen POS (ADR-1618): the branch board follows worker-driven
    // transitions too — CONFIRMED appears, CANCELLED (e.g. stop-listed) is
    // removed. Published after the commit; clients dedupe by orderVersion.
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
