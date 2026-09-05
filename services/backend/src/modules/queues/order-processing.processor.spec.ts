import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bullmq';
import { OrderStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderProcessingProcessor } from './order-processing.processor';
import {
  ORDER_PROCESSING_QUEUE,
  SEND_TO_KITCHEN_JOB,
} from './order-queues.service';

const ORDER_ID = '55555555-5555-5555-5555-555555555555';

describe('OrderProcessingProcessor — send-to-kitchen', () => {
  let processor: OrderProcessingProcessor;
  let prisma: {
    order: { findFirst: jest.Mock; update: jest.Mock };
    orderStatusHistory: { create: jest.Mock };
    $transaction: jest.Mock;
  };

  beforeEach(async () => {
    prisma = {
      order: { findFirst: jest.fn(), update: jest.fn().mockResolvedValue({}) },
      orderStatusHistory: { create: jest.fn().mockResolvedValue({}) },
      // Array transactions used by transitionWithHistory.
      $transaction: jest.fn().mockResolvedValue([]),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderProcessingProcessor,
        { provide: PrismaService, useValue: prisma },
        { provide: getQueueToken(ORDER_PROCESSING_QUEUE), useValue: { add: jest.fn() } },
      ],
    }).compile();

    processor = module.get(OrderProcessingProcessor);
  });

  const job = () =>
    ({ name: SEND_TO_KITCHEN_JOB, data: { orderId: ORDER_ID } }) as never;

  it('moves a CONFIRMED (paid) order to COOKING with an audit entry', async () => {
    prisma.order.findFirst.mockResolvedValue({ status: OrderStatus.CONFIRMED });

    await processor.process(job());

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.order.update).toHaveBeenCalledWith({
      where: { id: ORDER_ID },
      data: { status: OrderStatus.COOKING, version: { increment: 1 } },
    });
    expect(prisma.orderStatusHistory.create).toHaveBeenCalledWith({
      data: {
        orderId: ORDER_ID,
        previousStatus: OrderStatus.CONFIRMED,
        newStatus: OrderStatus.COOKING,
        reason: 'PAID_ONLINE',
      },
    });
  });

  it.each([
    OrderStatus.NEW,
    OrderStatus.COOKING,
    OrderStatus.READY,
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
