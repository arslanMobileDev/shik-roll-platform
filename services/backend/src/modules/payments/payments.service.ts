import {
  ConflictException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import {
  OrderStatus,
  Payment,
  PaymentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
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

    const session = await this.provider.createSession(sessionInput);

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
  async handleYooKassaWebhook(
    payload: YooKassaWebhookPayload,
  ): Promise<{ status: 'processed' | 'ignored' }> {
    if (payload?.type !== 'notification' || !payload.object?.id) {
      return { status: 'ignored' };
    }
    const externalId = payload.object.id;
    const event = payload.event;

    const payment = await this.prisma.payment.findFirst({
      where: { externalPaymentId: externalId },
      orderBy: { createdAt: 'desc' },
    });
    if (!payment) {
      this.logger.warn(`Webhook for unknown payment ${externalId} (${event})`);
      return { status: 'ignored' };
    }

    if (event === 'payment.succeeded' && payload.object.status === 'succeeded') {
      if (payment.status === PaymentStatus.SUCCEEDED) {
        return { status: 'processed' }; // duplicate delivery
      }
      if (payment.status === PaymentStatus.CANCELED) {
        this.logger.warn(
          `Succeeded webhook for canceled payment ${payment.id} — manual reconciliation required`,
        );
        return { status: 'ignored' };
      }
      const reported = payload.object.amount?.value;
      if (reported && reported !== payment.amount.toFixed(2)) {
        this.logger.warn(
          `Amount mismatch on payment ${payment.id}: expected ${payment.amount.toFixed(2)}, got ${reported}`,
        );
      }
      await this.applyPaymentSuccess(payment.id);
      return { status: 'processed' };
    }

    if (event === 'payment.canceled' && payload.object.status === 'canceled') {
      if (payment.status === PaymentStatus.PENDING) {
        await this.prisma.payment.update({
          where: { id: payment.id },
          data: { status: PaymentStatus.CANCELED },
        });
      }
      return { status: 'processed' };
    }

    return { status: 'ignored' };
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
   * Settle a successful payment atomically: mark the payment SUCCEEDED and,
   * while the order is still NEW, confirm it with an audit entry in
   * order_status_history (task contract: payment success confirms the order).
   * One transaction — the two writes never diverge.
   */
  private async applyPaymentSuccess(paymentId: string): Promise<Payment> {
    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.update({
        where: { id: paymentId },
        data: { status: PaymentStatus.SUCCEEDED },
      });
      const order = await tx.order.findUnique({ where: { id: payment.orderId } });
      if (order && !order.deletedAt && order.status === OrderStatus.NEW) {
        await tx.order.update({
          where: { id: order.id },
          data: { status: OrderStatus.CONFIRMED, version: { increment: 1 } },
        });
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            previousStatus: OrderStatus.NEW,
            newStatus: OrderStatus.CONFIRMED,
            reason: 'Online payment succeeded',
          },
        });
      } else if (order && order.status !== OrderStatus.NEW) {
        this.logger.warn(
          `Payment ${payment.id} succeeded but order ${order.id} is ${order.status} — status left unchanged`,
        );
      }
      return payment;
    });
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
