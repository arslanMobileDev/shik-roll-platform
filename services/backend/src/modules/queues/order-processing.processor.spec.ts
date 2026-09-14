import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bullmq';
import { OrderStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { OrderProcessingProcessor } from './order-processing.processor';
import {
  ORDER_PROCESSING_QUEUE,
  SEND_TO_KITCHEN_JOB,
} from './order-queues.service';

const D = (value: string | number) => new Prisma.Decimal(value);

const ORDER_ID = '55555555-5555-5555-5555-555555555555';
const BRANCH_ID = '22222222-2222-2222-2222-222222222222';
const MENU_ITEM_ID = '33333333-3333-3333-3333-333333333333';
const ORDER_ITEM_ID = '66666666-6666-6666-6666-666666666666';

describe('OrderProcessingProcessor — send-to-kitchen', () => {
  let processor: OrderProcessingProcessor;
  let prisma: {
    order: { findFirst: jest.Mock; update: jest.Mock };
    orderStatusHistory: { create: jest.Mock };
    stopListEntry: { findMany: jest.Mock };
    $transaction: jest.Mock;
  };
  let loyalty: { earnCashback: jest.Mock; refundOnCancel: jest.Mock };

  beforeEach(async () => {
    delete process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED;
    prisma = {
      order: { findFirst: jest.fn(), update: jest.fn().mockResolvedValue({}) },
      orderStatusHistory: { create: jest.fn().mockResolvedValue({}) },
      stopListEntry: { findMany: jest.fn().mockResolvedValue([]) },
      // Array transactions used by transitionWithHistory.
      $transaction: jest.fn().mockResolvedValue([]),
    };
    loyalty = {
      earnCashback: jest.fn().mockResolvedValue(undefined),
      refundOnCancel: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderProcessingProcessor,
        { provide: PrismaService, useValue: prisma },
        { provide: LoyaltyService, useValue: loyalty },
        { provide: getQueueToken(ORDER_PROCESSING_QUEUE), useValue: { add: jest.fn() } },
      ],
    }).compile();

    processor = module.get(OrderProcessingProcessor);
  });

  const job = () =>
    ({ name: SEND_TO_KITCHEN_JOB, data: { orderId: ORDER_ID } }) as never;

  it('keeps a CONFIRMED paid order unchanged in manual mode', async () => {
    prisma.order.findFirst.mockResolvedValue({ status: OrderStatus.CONFIRMED });

    await processor.process(job());

    expect(prisma.order.update).not.toHaveBeenCalled();
    expect(prisma.orderStatusHistory.create).not.toHaveBeenCalled();
  });

  it('keeps a NEW paid order unchanged in manual mode', async () => {
    prisma.order.findFirst.mockResolvedValue({ status: OrderStatus.NEW });

    await processor.process(job());

    expect(prisma.order.update).not.toHaveBeenCalled();
    expect(prisma.orderStatusHistory.create).not.toHaveBeenCalled();
  });

  it('does not restore transitions when a legacy flag is set', async () => {
    process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED = 'true';
    prisma.order.findFirst.mockResolvedValue({ status: OrderStatus.CONFIRMED });

    await processor.process(job());

    expect(prisma.order.update).not.toHaveBeenCalled();
    expect(prisma.orderStatusHistory.create).not.toHaveBeenCalled();
  });

  it.each([
    OrderStatus.COOKING,
    OrderStatus.READY,
    OrderStatus.ON_WAY,
    OrderStatus.COMPLETED,
    OrderStatus.CANCELLED,
  ])('skips the transition when the order is %s', async (status) => {
    prisma.order.findFirst.mockResolvedValue({ status });

    await processor.process(job());

    expect(prisma.order.update).not.toHaveBeenCalled();
    expect(prisma.orderStatusHistory.create).not.toHaveBeenCalled();
  });

  it('skips when the order is gone', async () => {
    prisma.order.findFirst.mockResolvedValue(null);

    await processor.process(job());

    expect(prisma.order.update).not.toHaveBeenCalled();
  });
});

describe('OrderProcessingProcessor — process-order (loyalty hooks, ADR-1614)', () => {
  let processor: OrderProcessingProcessor;
  let prisma: {
    order: { findFirst: jest.Mock; update: jest.Mock };
    orderItem: { update: jest.Mock };
    orderStatusHistory: { create: jest.Mock };
    stopListEntry: { findMany: jest.Mock };
    $transaction: jest.Mock;
  };
  let loyalty: { earnCashback: jest.Mock; refundOnCancel: jest.Mock };
  let queue: { add: jest.Mock };

  const makeOrder = (overrides: Record<string, unknown> = {}) => ({
    id: ORDER_ID,
    branchId: BRANCH_ID,
    status: OrderStatus.CONFIRMED,
    bonusDiscountAmount: D('0.00'),
    items: [
      {
        id: ORDER_ITEM_ID,
        orderId: ORDER_ID,
        menuItemId: MENU_ITEM_ID,
        name: 'Филадельфия',
        quantity: 2,
        unitPrice: D('400.00'),
        totalAmount: D('800.00'),
        comment: null,
        modifiers: [],
      },
    ],
    ...overrides,
  });

  beforeEach(async () => {
    delete process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED;
    prisma = {
      order: { findFirst: jest.fn(), update: jest.fn().mockResolvedValue({}) },
      orderItem: { update: jest.fn().mockResolvedValue({}) },
      orderStatusHistory: { create: jest.fn().mockResolvedValue({}) },
      stopListEntry: { findMany: jest.fn().mockResolvedValue([]) },
      $transaction: jest.fn().mockResolvedValue([]),
    };
    loyalty = {
      earnCashback: jest.fn().mockResolvedValue(undefined),
      refundOnCancel: jest.fn().mockResolvedValue(undefined),
    };
    queue = { add: jest.fn().mockResolvedValue({}) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderProcessingProcessor,
        { provide: PrismaService, useValue: prisma },
        { provide: LoyaltyService, useValue: loyalty },
        { provide: getQueueToken(ORDER_PROCESSING_QUEUE), useValue: queue },
      ],
    }).compile();

    processor = module.get(OrderProcessingProcessor);
  });

  const job = () => ({ name: 'process-order', data: { orderId: ORDER_ID } }) as never;

  it.each([
    ['0.00', '800'], ['100.00', '700'], ['100.25', '699.75'], ['800.00', '0'],
  ])('keeps checkout discount %s when recalculating totals', async (discount, expected) => {
    prisma.order.findFirst.mockResolvedValue(makeOrder({ bonusDiscountAmount: D(discount) }));

    await processor.process(job());

    const update = prisma.order.update.mock.calls[0][0].data;
    expect(update.subtotalAmount.toString()).toBe('800');
    expect(update.totalAmount.toString()).toBe(expected);
    expect(update.bonusDiscountAmount).toBeUndefined();
    expect(loyalty.refundOnCancel).not.toHaveBeenCalled();
  });

  it('preserves the discount and modifier totals across retries', async () => {
    const order = makeOrder({ bonusDiscountAmount: D('100.25') });
    const item = { ...order.items[0], unitPrice: D('400.10'),
      modifiers: [{ priceDelta: D('10.15'), quantity: 2 }] };
    prisma.order.findFirst.mockResolvedValue({ ...order, items: [item] });
    prisma.order.update.mockImplementation(async ({ data }) => {
      prisma.order.findFirst.mockResolvedValue({ ...order, ...data, items: [item] });
      return { ...order, ...data };
    });

    await processor.process(job());
    await processor.process(job());

    expect(prisma.order.update).toHaveBeenCalledTimes(2);
    for (const [args] of prisma.order.update.mock.calls) {
      expect(args.data.subtotalAmount.toString()).toBe('840.8');
      expect(args.data.totalAmount.toString()).toBe('740.55');
      expect(args.data.bonusDiscountAmount).toBeUndefined();
    }
    for (const [args] of prisma.orderItem.update.mock.calls) {
      expect(args.data.totalAmount.toString()).toBe('840.8');
    }
    expect(loyalty.refundOnCancel).not.toHaveBeenCalled();
    expect(loyalty.earnCashback).not.toHaveBeenCalled();
  });

  it('refunds the spent points when a stop-listed order is cancelled', async () => {
    prisma.order.findFirst.mockResolvedValue(makeOrder({ status: OrderStatus.NEW }));
    prisma.stopListEntry.findMany.mockResolvedValue([{ menuItemId: MENU_ITEM_ID }]);

    await processor.process(job());

    expect(loyalty.refundOnCancel).toHaveBeenCalledWith(ORDER_ID);
    expect(loyalty.earnCashback).not.toHaveBeenCalled();
  });

  it('retries a failed refund without repeating cancellation after the stop-list changes', async () => {
    prisma.order.findFirst.mockResolvedValue(makeOrder({ status: OrderStatus.NEW }));
    prisma.stopListEntry.findMany.mockResolvedValue([{ menuItemId: MENU_ITEM_ID }]);
    loyalty.refundOnCancel.mockRejectedValueOnce(new Error('loyalty unavailable'));
    await expect(processor.process(job())).rejects.toThrow('loyalty unavailable');
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);

    prisma.order.findFirst.mockResolvedValue(makeOrder({
      status: OrderStatus.CANCELLED, cancelReason: 'STOP_LISTED',
    }));
    prisma.stopListEntry.findMany.mockResolvedValue([]);
    await processor.process(job());
    await processor.process(job());

    expect(loyalty.refundOnCancel).toHaveBeenCalledTimes(3);
    expect(prisma.orderStatusHistory.create).toHaveBeenCalledTimes(1);
    expect(prisma.stopListEntry.findMany).toHaveBeenCalledTimes(1);
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.orderItem.update).not.toHaveBeenCalled();
  });

  it('does not refund when cancellation fails to commit', async () => {
    prisma.order.findFirst.mockResolvedValue(makeOrder({ status: OrderStatus.NEW }));
    prisma.stopListEntry.findMany.mockResolvedValue([{ menuItemId: MENU_ITEM_ID }]);
    prisma.$transaction.mockRejectedValue(new Error('database unavailable'));
    await expect(processor.process(job())).rejects.toThrow('database unavailable');
    expect(loyalty.refundOnCancel).not.toHaveBeenCalled();
  });

  it('leaves cancellation for another reason to its owning flow', async () => {
    prisma.order.findFirst.mockResolvedValue(makeOrder({
      status: OrderStatus.CANCELLED, cancelReason: 'CUSTOMER_REQUEST',
    }));
    await processor.process(job());
    expect(loyalty.refundOnCancel).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('does not touch loyalty while the order stays on the happy path', async () => {
    prisma.order.findFirst.mockResolvedValue(makeOrder());

    await processor.process(job());

    expect(loyalty.refundOnCancel).not.toHaveBeenCalled();
    expect(loyalty.earnCashback).not.toHaveBeenCalled();
  });

  it('does not schedule status timers for a NEW order in manual mode', async () => {
    prisma.order.findFirst.mockResolvedValue(makeOrder({ status: OrderStatus.NEW }));

    await processor.process(job());

    expect(queue.add).not.toHaveBeenCalled();
    expect(prisma.orderStatusHistory.create).not.toHaveBeenCalled();
  });
});


describe('OrderProcessingProcessor — retired status timers', () => {
  it.each([OrderStatus.CONFIRMED, OrderStatus.COOKING, OrderStatus.READY,
    OrderStatus.ON_WAY, OrderStatus.COMPLETED])(
    'ignores a persisted timer targeting %s even with legacy emulation enabled',
    async (to) => {
      const previous = process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED;
      process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED = 'true';
      try {
        const prisma = { order: { findFirst: jest.fn(), update: jest.fn() },
          $transaction: jest.fn() };
        const processor = new OrderProcessingProcessor(prisma as unknown as PrismaService,
          { refundOnCancel: jest.fn() } as unknown as LoyaltyService);
        await processor.process({ id: 'legacy-job', name: 'status-timer',
          data: { orderId: ORDER_ID, to } } as never);
        expect(prisma.order.findFirst).not.toHaveBeenCalled();
        expect(prisma.order.update).not.toHaveBeenCalled();
        expect(prisma.$transaction).not.toHaveBeenCalled();
      } finally {
        if (previous === undefined) delete process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED;
        else process.env.ORDER_AUTO_STATUS_ADVANCE_ENABLED = previous;
      }
    },
  );
});
