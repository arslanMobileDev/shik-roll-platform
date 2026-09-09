import {
  ConflictException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import {
  OrderStatus,
  Payment,
  PaymentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { OrdersEventsService } from '../orders/orders-events.service';
import { OrderQueuesService } from '../queues/order-queues.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { KitchenEventsService } from '../kitchen/kitchen-events.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import {
  OrderPaymentStatusEntity,
  PaymentEntity,
} from './entities/payment.entity';
import { toPaymentEntity } from './mappers/payment.mapper';
import {
  CreatePaymentSessionInput,
  PAYMENT_PROVIDER_ADAPTER,
  PaymentProviderAdapter,
  ReceiptLine,
  YooKassaWebhookPayload,
} from './payments.types';

const ORDER_FOR_PAYMENT_INCLUDE = {
  items: { include: { modifiers: true } },
  customer: true,
} satisfies Prisma.OrderInclude;

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(PAYMENT_PROVIDER_ADAPTER)
    private readonly provider: PaymentProviderAdapter,
    private readonly queues: OrderQueuesService,
    private readonly ordersEvents: OrdersEventsService,
    private readonly loyalty: LoyaltyService,
    @Optional() private readonly kitchenEvents?: KitchenEventsService,
  ) {}

  /**
   * Create an online payment session for an order. The amount is always the
   * server-side order total — client-supplied amounts are never accepted.
   * Idempotent by construction: an order with a SUCCEEDED payment is rejected
   * (409 ORDER_ALREADY_PAID), an existing PENDING attempt is returned as-is,
   * and the idempotence_key unique constraint guards against races.
   */
  async createPayment(dto: CreatePaymentDto): Promise<PaymentEntity> {
    const order = await this.prisma.order.findFirst({
      where: { id: dto.orderId, deletedAt: null },
      include: ORDER_FOR_PAYMENT_INCLUDE,
    });
    if (!order) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${dto.orderId} not found`,
      });
    }

    const attempts = await this.prisma.payment.findMany({
      where: { orderId: order.id },
      orderBy: { createdAt: 'desc' },
    });
    if (attempts.some((attempt) => attempt.status === PaymentStatus.SUCCEEDED)) {
      throw new ConflictException({
        statusCode: 409,
        code: 'ORDER_ALREADY_PAID',
        message: `Order ${order.id} is already paid`,
      });
    }
    const pending = attempts.find(
      (attempt) => attempt.status === PaymentStatus.PENDING,
    );
    if (pending) {
      // Idempotent retry: hand the customer the existing payment session.
      return toPaymentEntity(pending);
    }

    const idempotenceKey = `pay_${order.id}_${attempts.length + 1}`;
    const paymentId = randomUUID();

    const sessionInput: CreatePaymentSessionInput = {
      paymentId,
      orderId: order.id,
      orderNumber: order.orderNumber,
      idempotenceKey,
      amount: order.totalAmount,
      currency: order.currency,
      description: `Заказ ${order.orderNumber}`,
      customer: order.customer
        ? { email: order.customer.email, phone: order.customer.phone }
        : undefined,
      receiptLines: this.buildReceiptLines(order),
    };

    const session = await this.provider.createPayment(sessionInput);

    let payment: Payment;
    try {
      payment = await this.prisma.payment.create({
        data: {
          id: paymentId,
          order: { connect: { id: order.id } },
          provider: this.provider.provider,
          status: session.status,
          amount: order.totalAmount,
          currency: order.currency,
          paymentUrl: session.paymentUrl,
          externalPaymentId: session.externalPaymentId,
          idempotenceKey,
        },
      });
    } catch (error) {
      // Lost a race on the idempotence key — return the attempt that won.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const winner = await this.prisma.payment.findFirst({
          where: { orderId: order.id, status: PaymentStatus.PENDING },
          orderBy: { createdAt: 'desc' },
        });
        if (winner) return toPaymentEntity(winner);
      }
      throw error;
    }

    // Providers may complete synchronously (dev Mock): settle immediately.
    if (payment.status === PaymentStatus.SUCCEEDED) {
      payment = await this.applyPaymentSuccess(payment.id);
    }
    return toPaymentEntity(payment);
  }

  /**
   * YooKassa webhook (https://yookassa.ru/developers/using-api/webhooks).
   * Must always answer 200 fast — unknown payments and unsupported events
   * are acknowledged as 'ignored' so the provider stops retrying. Repeated
   * delivery of payment.succeeded is a no-op (idempotent).
   */
  async handleWebhook(
    headers: Record<string, string | string[] | undefined>,
    payload: YooKassaWebhookPayload,
  ): Promise<{ status: 'processed' | 'ignored' }> {
    const event = this.provider.parseWebhookEvent(payload);
    if (!event) {
      return { status: 'ignored' };
    }

    if (!(await this.provider.verifyWebhook(headers, payload))) {
      this.logger.warn(`Unverified webhook for payment ${event.paymentId}`);
      return { status: 'ignored' };
    }

    const payment = await this.prisma.payment.findFirst({
      where: { externalPaymentId: event.paymentId },
      orderBy: { createdAt: 'desc' },
    });
    if (!payment) {
      this.logger.warn(
        `Webhook for unknown payment ${event.paymentId} (${event.event})`,
      );
      return { status: 'ignored' };
    }
    if (event.orderId && event.orderId !== payment.orderId) {
      this.logger.warn(`Webhook order mismatch for payment ${event.paymentId}`);
      return { status: 'ignored' };
    }

    if (event.event === 'payment.succeeded') {
      if (payment.status === PaymentStatus.SUCCEEDED) {
        return { status: 'processed' }; // duplicate delivery
      }
      if (payment.status === PaymentStatus.CANCELED) {
        this.logger.warn(
          `Succeeded webhook for canceled payment ${payment.id} — manual reconciliation required`,
        );
        return { status: 'ignored' };
      }
      const reported = payload.object?.amount?.value;
      if (reported && reported !== payment.amount.toFixed(2)) {
        this.logger.warn(
          `Amount mismatch on payment ${payment.id}: expected ${payment.amount.toFixed(2)}, got ${reported}`,
        );
      }
      await this.applyPaymentSuccess(payment.id);
      return { status: 'processed' };
    }

    if (event.event === 'payment.canceled') {
      if (payment.status === PaymentStatus.CANCELED) {
        return { status: 'processed' };
      }
      if (payment.status === PaymentStatus.SUCCEEDED) {
        this.logger.warn(
          `Canceled webhook for succeeded payment ${payment.id} — ignored`,
        );
        return { status: 'ignored' };
      }
      await this.applyPaymentCancellation(payment.id);
      return { status: 'processed' };
    }

    return { status: 'ignored' };
  }

  private async applyPaymentCancellation(paymentId: string): Promise<void> {
    let canceledOrderId: string | undefined;
    await this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.update({
        where: { id: paymentId },
        data: { status: PaymentStatus.CANCELED },
      });
      const order = await tx.order.findUnique({ where: { id: payment.orderId } });
      if (
        order &&
        !order.deletedAt &&
        order.status === OrderStatus.PENDING_PAYMENT
      ) {
        await tx.order.update({
          where: { id: order.id },
          data: {
            status: OrderStatus.CANCELLED,
            cancelledAt: new Date(),
            cancelReason: 'Online payment canceled',
            version: { increment: 1 },
          },
        });
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            previousStatus: OrderStatus.PENDING_PAYMENT,
            newStatus: OrderStatus.CANCELLED,
            reason: 'Online payment canceled',
          },
        });
        canceledOrderId = order.id;
      }
    });

    if (canceledOrderId) {
      await this.loyalty.refundOnCancel(canceledOrderId);
      await this.kitchenEvents?.publishOrderChanged(canceledOrderId);
    }
  }

  /** Payment status check for an order: the latest attempt, if any. */
  async getOrderPayment(orderId: string): Promise<OrderPaymentStatusEntity> {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, deletedAt: null },
      select: { id: true },
    });
    if (!order) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'ORDER_NOT_FOUND',
        message: `Order ${orderId} not found`,
      });
    }
    const payment = await this.prisma.payment.findFirst({
      where: { orderId },
      orderBy: { createdAt: 'desc' },
    });
    return { orderId, payment: payment ? toPaymentEntity(payment) : null };
  }

  /**
   * Settle a successful payment: mark the payment SUCCEEDED and, while the
   * order is still NEW, confirm it with an audit entry in
   * order_status_history (task contract: payment success confirms the
   * order). One transaction — the two writes never diverge. After commit,
   * the paid order is dispatched to the kitchen via BullMQ (task contract:
   * payment success enqueues kitchen processing); the queue add is
   * deliberately outside the transaction — a rolled-back settlement must
   * never reach the kitchen, and the dedup jobId absorbs retries.
   */
  private async applyPaymentSuccess(paymentId: string): Promise<Payment> {
    let dispatchToKitchen = false;
    let becameVisibleToKitchen:
      | {
          id: string;
          orderNumber: string;
          branchId: string;
          status: OrderStatus;
        }
      | undefined;
    const payment = await this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.update({
        where: { id: paymentId },
        data: { status: PaymentStatus.SUCCEEDED },
      });
      const order = await tx.order.findUnique({ where: { id: payment.orderId } });
      if (
        order &&
        !order.deletedAt &&
        (order.status === OrderStatus.PENDING_PAYMENT ||
          order.status === OrderStatus.NEW)
      ) {
        const previousStatus = order.status;
        await tx.order.update({
          where: { id: order.id },
          data: {
            status: OrderStatus.CONFIRMED,
            confirmedAt: new Date(),
            version: { increment: 1 },
          },
        });
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            previousStatus,
            newStatus: OrderStatus.CONFIRMED,
            reason: 'Online payment succeeded',
          },
        });
        dispatchToKitchen = true;
        if (previousStatus === OrderStatus.PENDING_PAYMENT) {
          becameVisibleToKitchen = {
            id: order.id,
            orderNumber: order.orderNumber,
            branchId: order.branchId,
            status: OrderStatus.CONFIRMED,
          };
        }
      } else if (order && !order.deletedAt && order.status === OrderStatus.CONFIRMED) {
        // Already confirmed (e.g. by the POS auto-confirm path) — the
        // kitchen still waits for the paid signal before starting.
        dispatchToKitchen = true;
      } else if (
        order &&
        order.status !== OrderStatus.NEW &&
        order.status !== OrderStatus.PENDING_PAYMENT
      ) {
        this.logger.warn(
          `Payment ${payment.id} succeeded but order ${order.id} is ${order.status} — status left unchanged`,
        );
      }
      return payment;
    });
    if (becameVisibleToKitchen) {
      this.ordersEvents.emitKdsEvent({
        eventType: 'ORDER_CREATED',
        orderId: becameVisibleToKitchen.id,
        orderNumber: becameVisibleToKitchen.orderNumber,
        branchId: becameVisibleToKitchen.branchId,
        status: becameVisibleToKitchen.status,
        timestamp: new Date().toISOString(),
      });
      await this.kitchenEvents?.publishOrderChanged(becameVisibleToKitchen.id);
    }
    if (dispatchToKitchen) {
      await this.queues.sendToKitchen(payment.orderId);
    }
    return payment;
  }

  /**
   * 54-ФЗ receipt lines from the order snapshot: one line per order item,
   * per-unit price including modifiers, so sum(line x quantity) equals the
   * order total exactly (modifier names are appended to the description).
   */
  private buildReceiptLines(
    order: Prisma.OrderGetPayload<{
      include: typeof ORDER_FOR_PAYMENT_INCLUDE;
    }>,
  ): ReceiptLine[] {
    return order.items.map((item) => {
      const modifierDelta = item.modifiers.reduce(
        (sum, modifier) =>
          sum.plus(modifier.priceDelta.times(modifier.quantity)),
        new Prisma.Decimal(0),
      );
      const modifierNames = item.modifiers.map((modifier) => modifier.name);
      return {
        description: modifierNames.length
          ? `${item.name} (+${modifierNames.join(', ')})`
          : item.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice.plus(modifierDelta),
      };
    });
  }
}
