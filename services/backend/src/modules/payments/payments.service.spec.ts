import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import {
  OrderStatus,
  OrderType,
  PaymentProvider,
  PaymentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PaymentsService } from './payments.service';
import {
  PAYMENT_PROVIDER_ADAPTER,
  PaymentSessionResult,
} from './payments.types';

const D = (value: string | number) => new Prisma.Decimal(value);

const BRAND_ID = '11111111-1111-1111-1111-111111111111';
const BRANCH_ID = '22222222-2222-2222-2222-222222222222';
const ORDER_ID = '55555555-5555-5555-5555-555555555555';
const CUSTOMER_ID = '88888888-8888-8888-8888-888888888888';
const PAYMENT_ID = '99999999-9999-9999-9999-999999999999';

function makeOrderRecord(status: OrderStatus = OrderStatus.NEW) {
  return {
    id: ORDER_ID,
    orderNumber: 'AAAA-20260904-0001',
    status,
    type: OrderType.TAKEAWAY,
    brandId: BRAND_ID,
    branchId: BRANCH_ID,
    customerId: CUSTOMER_ID,
    tableNumber: null,
    deliveryAddress: null,
    comment: null,
    subtotalAmount: D('500.00'),
    totalAmount: D('500.00'),
    currency: 'RUB',
    estimatedReadyAt: null,
    completedAt: null,
    cancelledAt: null,
    cancelReason: null,
    createdAt: new Date('2026-09-04T10:00:00Z'),
    updatedAt: new Date('2026-09-04T10:00:00Z'),
    deletedAt: null,
    createdBy: null,
    updatedBy: null,
    version: 1,
    items: [
      {
        id: '66666666-6666-6666-6666-666666666666',
        orderId: ORDER_ID,
        menuItemId: '33333333-3333-3333-3333-333333333333',
        name: 'Филадельфия',
        quantity: 1,
        unitPrice: D('450.00'),
        totalAmount: D('500.00'),
        comment: null,
        createdAt: new Date('2026-09-04T10:00:00Z'),
        updatedAt: new Date('2026-09-04T10:00:00Z'),
        modifiers: [
          {
            id: '77777777-7777-7777-7777-777777777777',
            orderItemId: '66666666-6666-6666-6666-666666666666',
            modifierItemId: '44444444-4444-4444-4444-444444444444',
            name: 'Икра тобико',
            priceDelta: D('50.00'),
            quantity: 1,
            createdAt: new Date('2026-09-04T10:00:00Z'),
          },
        ],
      },
    ],
    customer: {
      id: CUSTOMER_ID,
      phone: '+79000000000',
      name: null,
      email: null,
      createdAt: new Date('2026-09-04T10:00:00Z'),
      updatedAt: new Date('2026-09-04T10:00:00Z'),
    },
  };
}

function makePaymentRecord(overrides: Record<string, unknown> = {}) {
  return {
    id: PAYMENT_ID,
    orderId: ORDER_ID,
    provider: PaymentProvider.YOOKASSA,
    status: PaymentStatus.PENDING,
    amount: D('500.00'),
    currency: 'RUB',
    paymentUrl: 'https://yoomoney.ru/checkout/payments/v2/contract?orderId=ext-1',
    externalPaymentId: 'ext-1',
    idempotenceKey: `pay_${ORDER_ID}_1`,
    createdAt: new Date('2026-09-04T10:00:00Z'),
    updatedAt: new Date('2026-09-04T10:00:00Z'),
    ...overrides,
  };
}

describe('PaymentsService', () => {
  let service: PaymentsService;
  let prisma: {
    order: { findFirst: jest.Mock; findUnique: jest.Mock; update: jest.Mock };
    payment: {
      findMany: jest.Mock;
      findFirst: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
    };
    orderStatusHistory: { create: jest.Mock };
    $transaction: jest.Mock;
  };
  let adapter: { provider: PaymentProvider; createSession: jest.Mock };

  const pendingSession: PaymentSessionResult = {
    externalPaymentId: 'ext-1',
    paymentUrl: 'https://yoomoney.ru/checkout/payments/v2/contract?orderId=ext-1',
    status: PaymentStatus.PENDING,
  };

  beforeEach(async () => {
    prisma = {
      order: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      payment: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      orderStatusHistory: { create: jest.fn() },
      // Interactive transactions run against the same mock.
      $transaction: jest.fn((cb: (tx: unknown) => unknown) => cb(prisma)),
    };
    adapter = {
      provider: PaymentProvider.YOOKASSA,
      createSession: jest.fn().mockResolvedValue(pendingSession),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: PrismaService, useValue: prisma },
        { provide: PAYMENT_PROVIDER_ADAPTER, useValue: adapter },
      ],
    }).compile();

    service = module.get(PaymentsService);
  });

  describe('createPayment', () => {
    it('creates a payment with the server-side order total and receipt lines', async () => {
      prisma.order.findFirst.mockResolvedValue(makeOrderRecord());
      prisma.payment.findMany.mockResolvedValue([]);
      prisma.payment.create.mockImplementation(({ data }) =>
        Promise.resolve(makePaymentRecord({ id: data.id, status: data.status })),
      );

      const result = await service.createPayment({ orderId: ORDER_ID });

      expect(adapter.createSession).toHaveBeenCalledTimes(1);
      const sessionInput = adapter.createSession.mock.calls[0][0];
      expect(sessionInput.amount.toFixed(2)).toBe('500.00');
      expect(sessionInput.currency).toBe('RUB');
      expect(sessionInput.idempotenceKey).toBe(`pay_${ORDER_ID}_1`);
      expect(sessionInput.customer).toEqual({
        email: null,
        phone: '+79000000000',
      });
      // 54-ФЗ receipt: unit price includes modifiers (450 + 50).
      expect(sessionInput.receiptLines).toEqual([
        {
          description: 'Филадельфия (+Икра тобико)',
          quantity: 1,
          unitPrice: D('500.00'),
        },
      ]);

      expect(prisma.payment.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            provider: PaymentProvider.YOOKASSA,
            status: PaymentStatus.PENDING,
            idempotenceKey: `pay_${ORDER_ID}_1`,
          }),
        }),
      );
      expect(prisma.payment.create.mock.calls[0][0].data.amount.toFixed(2)).toBe(
        '500.00',
      );
      expect(result.status).toBe(PaymentStatus.PENDING);
      expect(result.paymentUrl).toBe(pendingSession.paymentUrl);
      // A pending payment never touches the order.
      expect(prisma.order.update).not.toHaveBeenCalled();
    });

    it('settles a synchronously succeeded session (Mock provider)', async () => {
      adapter.createSession.mockResolvedValue({
        ...pendingSession,
        status: PaymentStatus.SUCCEEDED,
      });
      prisma.order.findFirst.mockResolvedValue(makeOrderRecord());
      prisma.payment.findMany.mockResolvedValue([]);
      prisma.payment.create.mockImplementation(({ data }) =>
        Promise.resolve(makePaymentRecord({ id: data.id, status: data.status })),
      );
      prisma.payment.update.mockResolvedValue(
        makePaymentRecord({ status: PaymentStatus.SUCCEEDED }),
      );
      prisma.order.findUnique.mockResolvedValue(makeOrderRecord());
      prisma.order.update.mockResolvedValue(
        makeOrderRecord(OrderStatus.CONFIRMED),
      );
      prisma.orderStatusHistory.create.mockResolvedValue({});

      const result = await service.createPayment({ orderId: ORDER_ID });

      expect(result.status).toBe(PaymentStatus.SUCCEEDED);
      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
      expect(prisma.order.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: OrderStatus.CONFIRMED }),
        }),
      );
      expect(prisma.orderStatusHistory.create).toHaveBeenCalledWith({
        data: {
          orderId: ORDER_ID,
          previousStatus: OrderStatus.NEW,
          newStatus: OrderStatus.CONFIRMED,
          reason: 'Online payment succeeded',
        },
      });
    });

    it('returns the existing pending attempt on a repeated call (idempotent)', async () => {
      const pending = makePaymentRecord();
      prisma.order.findFirst.mockResolvedValue(makeOrderRecord());
      prisma.payment.findMany.mockResolvedValue([pending]);

      const result = await service.createPayment({ orderId: ORDER_ID });

      expect(result.id).toBe(pending.id);
      expect(result.paymentUrl).toBe(pending.paymentUrl);
      expect(adapter.createSession).not.toHaveBeenCalled();
      expect(prisma.payment.create).not.toHaveBeenCalled();
    });

    it('rejects a second payment for an already paid order', async () => {
      prisma.order.findFirst.mockResolvedValue(makeOrderRecord());
      prisma.payment.findMany.mockResolvedValue([
        makePaymentRecord({ status: PaymentStatus.SUCCEEDED }),
      ]);

      await expect(service.createPayment({ orderId: ORDER_ID })).rejects.toThrow(
        ConflictException,
      );
      await expect(
        service.createPayment({ orderId: ORDER_ID }),
      ).rejects.toMatchObject({
        response: expect.objectContaining({ code: 'ORDER_ALREADY_PAID' }),
      });
      expect(adapter.createSession).not.toHaveBeenCalled();
    });

    it('404 ORDER_NOT_FOUND for a missing order', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(service.createPayment({ orderId: ORDER_ID })).rejects.toThrow(
        NotFoundException,
      );
      expect(adapter.createSession).not.toHaveBeenCalled();
    });

    it('recovers from an idempotence-key race by returning the winning attempt', async () => {
      const winner = makePaymentRecord({ id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' });
      prisma.order.findFirst.mockResolvedValue(makeOrderRecord());
      prisma.payment.findMany.mockResolvedValue([]);
      prisma.payment.create.mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
          code: 'P2002',
          clientVersion: '6.14.0',
        }),
      );
      prisma.payment.findFirst.mockResolvedValue(winner);

      const result = await service.createPayment({ orderId: ORDER_ID });

      expect(result.id).toBe(winner.id);
    });
  });

  describe('handleYooKassaWebhook', () => {
    const succeededPayload = {
      type: 'notification',
      event: 'payment.succeeded',
      object: {
        id: 'ext-1',
        status: 'succeeded',
        paid: true,
        amount: { value: '500.00', currency: 'RUB' },
      },
    };

    it('marks the payment SUCCEEDED and confirms the order with an audit entry', async () => {
      prisma.payment.findFirst.mockResolvedValue(makePaymentRecord());
      prisma.payment.update.mockResolvedValue(
        makePaymentRecord({ status: PaymentStatus.SUCCEEDED }),
      );
      prisma.order.findUnique.mockResolvedValue(makeOrderRecord());
      prisma.order.update.mockResolvedValue(
        makeOrderRecord(OrderStatus.CONFIRMED),
      );
      prisma.orderStatusHistory.create.mockResolvedValue({});

      const result = await service.handleYooKassaWebhook(succeededPayload);

      expect(result).toEqual({ status: 'processed' });
      expect(prisma.payment.update).toHaveBeenCalledWith({
        where: { id: PAYMENT_ID },
        data: { status: PaymentStatus.SUCCEEDED },
      });
      expect(prisma.orderStatusHistory.create).toHaveBeenCalledWith({
        data: {
          orderId: ORDER_ID,
          previousStatus: OrderStatus.NEW,
          newStatus: OrderStatus.CONFIRMED,
          reason: 'Online payment succeeded',
        },
      });
    });

    it('is idempotent on duplicate payment.succeeded delivery', async () => {
      prisma.payment.findFirst.mockResolvedValue(
        makePaymentRecord({ status: PaymentStatus.SUCCEEDED }),
      );

      const result = await service.handleYooKassaWebhook(succeededPayload);

      expect(result).toEqual({ status: 'processed' });
      expect(prisma.payment.update).not.toHaveBeenCalled();
      expect(prisma.orderStatusHistory.create).not.toHaveBeenCalled();
    });

    it('does not regress an order that already left NEW', async () => {
      prisma.payment.findFirst.mockResolvedValue(makePaymentRecord());
      prisma.payment.update.mockResolvedValue(
        makePaymentRecord({ status: PaymentStatus.SUCCEEDED }),
      );
      prisma.order.findUnique.mockResolvedValue(
        makeOrderRecord(OrderStatus.COOKING),
      );

      const result = await service.handleYooKassaWebhook(succeededPayload);

      expect(result).toEqual({ status: 'processed' });
      expect(prisma.payment.update).toHaveBeenCalled();
      expect(prisma.order.update).not.toHaveBeenCalled();
      expect(prisma.orderStatusHistory.create).not.toHaveBeenCalled();
    });

    it('cancels a pending payment on payment.canceled', async () => {
      prisma.payment.findFirst.mockResolvedValue(makePaymentRecord());
      prisma.payment.update.mockResolvedValue(
        makePaymentRecord({ status: PaymentStatus.CANCELED }),
      );

      const result = await service.handleYooKassaWebhook({
        type: 'notification',
        event: 'payment.canceled',
        object: { id: 'ext-1', status: 'canceled', paid: false },
      });

      expect(result).toEqual({ status: 'processed' });
      expect(prisma.payment.update).toHaveBeenCalledWith({
        where: { id: PAYMENT_ID },
        data: { status: PaymentStatus.CANCELED },
      });
      expect(prisma.order.update).not.toHaveBeenCalled();
    });

    it('ignores webhooks for unknown payments', async () => {
      prisma.payment.findFirst.mockResolvedValue(null);

      const result = await service.handleYooKassaWebhook(succeededPayload);

      expect(result).toEqual({ status: 'ignored' });
      expect(prisma.payment.update).not.toHaveBeenCalled();
    });

    it('ignores malformed payloads', async () => {
      expect(await service.handleYooKassaWebhook({})).toEqual({
        status: 'ignored',
      });
      expect(
        await service.handleYooKassaWebhook({ type: 'notification' }),
      ).toEqual({ status: 'ignored' });
    });
  });

  describe('getOrderPayment', () => {
    it('returns the latest payment attempt', async () => {
      prisma.order.findFirst.mockResolvedValue({ id: ORDER_ID });
      prisma.payment.findFirst.mockResolvedValue(makePaymentRecord());

      const result = await service.getOrderPayment(ORDER_ID);

      expect(result.orderId).toBe(ORDER_ID);
      expect(result.payment?.id).toBe(PAYMENT_ID);
      expect(result.payment?.status).toBe(PaymentStatus.PENDING);
    });

    it('returns null payment when the order has no attempts', async () => {
      prisma.order.findFirst.mockResolvedValue({ id: ORDER_ID });
      prisma.payment.findFirst.mockResolvedValue(null);

      const result = await service.getOrderPayment(ORDER_ID);

      expect(result).toEqual({ orderId: ORDER_ID, payment: null });
    });

    it('404 ORDER_NOT_FOUND for a missing order', async () => {
      prisma.order.findFirst.mockResolvedValue(null);

      await expect(service.getOrderPayment(ORDER_ID)).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
