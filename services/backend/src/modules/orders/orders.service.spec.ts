import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { OrderStatus, OrderType, Prisma, ProductStatus } from '@prisma/client';
import { firstValueFrom, of, take, toArray } from 'rxjs';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CouriersEventsService,
  OrderTrackingEvent,
} from '../couriers/couriers-events.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import { OrderQueuesService } from '../queues/order-queues.service';
import { OrdersRepository } from './orders.repository';
import { OrdersService } from './orders.service';

const D = (value: string | number) => new Prisma.Decimal(value);

const BRAND_ID = '11111111-1111-1111-1111-111111111111';
const BRANCH_ID = '22222222-2222-2222-2222-222222222222';
const MENU_ITEM_ID = '33333333-3333-3333-3333-333333333333';
const MODIFIER_ID = '44444444-4444-4444-4444-444444444444';
const ORDER_ID = '55555555-5555-5555-5555-555555555555';
const CUSTOMER_ID = '10101010-1010-1010-1010-101010101010';

function makeOrderRecord(status: OrderStatus = OrderStatus.NEW) {
  return {
    id: ORDER_ID,
    orderNumber: 'AAAA-20260830-0001',
    status,
    type: OrderType.DINE_IN,
    brandId: BRAND_ID,
    branchId: BRANCH_ID,
    customerId: CUSTOMER_ID,
    courierId: null as string | null,
    tableNumber: '7',
    deliveryAddress: null,
    comment: null,
    subtotalAmount: D('800.00'),
    bonusDiscountAmount: D('0.00'),
    appliedBonusPoints: 0,
    totalAmount: D('800.00'),
    currency: 'RUB',
    estimatedReadyAt: null,
    completedAt: null,
    cancelledAt: null,
    cancelReason: null,
    createdAt: new Date('2026-08-30T10:00:00Z'),
    updatedAt: new Date('2026-08-30T10:00:00Z'),
    deletedAt: null,
    createdBy: null,
    updatedBy: null,
    version: 1,
    items: [
      {
        id: '66666666-6666-6666-6666-666666666666',
        orderId: ORDER_ID,
        menuItemId: MENU_ITEM_ID,
        name: 'Филадельфия',
        quantity: 2,
        unitPrice: D('400.00'),
        totalAmount: D('800.00'),
        comment: null,
        createdAt: new Date('2026-08-30T10:00:00Z'),
        updatedAt: new Date('2026-08-30T10:00:00Z'),
        modifiers: [
          {
            id: '77777777-7777-7777-7777-777777777777',
            orderItemId: '66666666-6666-6666-6666-666666666666',
            modifierItemId: MODIFIER_ID,
            name: 'Икра тобико',
            priceDelta: D('50.00'),
            quantity: 1,
            createdAt: new Date('2026-08-30T10:00:00Z'),
          },
        ],
      },
    ],
  };
}

describe('OrdersService', () => {
  let service: OrdersService;
  let repository: {
    list: jest.Mock;
    findById: jest.Mock;
    create: jest.Mock;
    transitionStatus: jest.Mock;
    nextOrderSequence: jest.Mock;
  };
  let queues: { scheduleOrderProcessing: jest.Mock };
  let prisma: {
    menuItem: { findMany: jest.Mock };
    modifierItem: { findMany: jest.Mock };
    $transaction: jest.Mock;
  };
  let loyalty: {
    assertSpendAllowed: jest.Mock;
    spendWithinTransaction: jest.Mock;
    earnCashback: jest.Mock;
    refundOnCancel: jest.Mock;
  };
  let couriersEvents: {
    emitOrderEvent: jest.Mock;
    emitOrderTrackingEvent: jest.Mock;
    getOrderTrackingStream: jest.Mock;
  };

  beforeEach(async () => {
    repository = {
      list: jest.fn(),
      findById: jest.fn(),
      create: jest.fn(),
      transitionStatus: jest.fn(),
      nextOrderSequence: jest.fn().mockResolvedValue(0),
    };
    queues = { scheduleOrderProcessing: jest.fn().mockResolvedValue(undefined) };
    prisma = {
      menuItem: { findMany: jest.fn() },
      modifierItem: { findMany: jest.fn() },
      // Interactive transactions hand the callback a bare client stub; the
      // repository is mocked, so the client itself is never exercised.
      $transaction: jest.fn((callback: (client: unknown) => unknown) =>
        callback({}),
      ),
    };
    loyalty = {
      assertSpendAllowed: jest.fn().mockResolvedValue(undefined),
      spendWithinTransaction: jest.fn().mockResolvedValue(undefined),
      earnCashback: jest.fn().mockResolvedValue(undefined),
      refundOnCancel: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: OrdersRepository, useValue: repository },
        { provide: OrderQueuesService, useValue: queues },
        { provide: PrismaService, useValue: prisma },
        { provide: LoyaltyService, useValue: loyalty },
        {
          provide: CouriersEventsService,
          useValue: {
            emitOrderEvent: jest.fn(),
            emitOrderTrackingEvent: jest.fn(),
            getOrderTrackingStream: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(OrdersService);
    couriersEvents = module.get(CouriersEventsService);
  });

  describe('list', () => {
    it('returns a paginated page', async () => {
      repository.list.mockResolvedValue({ records: [makeOrderRecord()], total: 1 });
      const page = await service.list({ page: 1, limit: 20 });
      expect(page.meta).toEqual({ page: 1, limit: 20, total: 1, totalPages: 1 });
      expect(page.data).toHaveLength(1);
      expect(page.data[0].orderNumber).toBe('AAAA-20260830-0001');
      expect(page.data[0].items[0].modifiers[0].priceDelta).toBe(50);
    });

    it('passes filters to the repository', async () => {
      repository.list.mockResolvedValue({ records: [], total: 0 });
      await service.list({
        brandId: BRAND_ID,
        branchId: BRANCH_ID,
        status: OrderStatus.READY,
        page: 2,
        limit: 10,
      });
      expect(repository.list).toHaveBeenCalledWith({
        brandId: BRAND_ID,
        branchId: BRANCH_ID,
        status: OrderStatus.READY,
        page: 2,
        limit: 10,
      });
    });
  });

  describe('getById', () => {
    it('throws ORDER_NOT_FOUND when missing', async () => {
      repository.findById.mockResolvedValue(null);
      await expect(service.getById(ORDER_ID)).rejects.toMatchObject({
        response: { code: 'ORDER_NOT_FOUND' },
      });
      await expect(service.getById(ORDER_ID)).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('create', () => {
    const dto = {
      type: OrderType.DINE_IN,
      brandId: BRAND_ID,
      branchId: BRANCH_ID,
      tableNumber: '7',
      items: [
        {
          menuItemId: MENU_ITEM_ID,
          quantity: 2,
          modifiers: [{ modifierItemId: MODIFIER_ID, quantity: 1 }],
        },
      ],
    };

    beforeEach(() => {
      prisma.menuItem.findMany.mockResolvedValue([
        {
          id: MENU_ITEM_ID,
          name: 'Филадельфия',
          basePrice: D('400.00'),
          status: ProductStatus.PUBLISHED,
          prices: [],
        },
      ]);
      prisma.modifierItem.findMany.mockResolvedValue([
        { id: MODIFIER_ID, name: 'Икра тобико', price: D('50.00') },
      ]);
      repository.create.mockResolvedValue(makeOrderRecord());
    });

    it('resolves prices on the server and schedules background processing', async () => {
      const result = await service.create(dto);

      expect(repository.create).toHaveBeenCalledTimes(1);
      const createArg = repository.create.mock.calls[0][0];
      // (400 + 50) * 2 = 900
      expect(createArg.subtotalAmount.toString()).toBe('900');
      expect(createArg.totalAmount.toString()).toBe('900');
      expect(createArg.status).toBe(OrderStatus.NEW);
      expect(createArg.items.create[0].unitPrice.toString()).toBe('400');
      expect(createArg.items.create[0].totalAmount.toString()).toBe('900');
      expect(createArg.items.create[0].modifiers.create[0].name).toBe('Икра тобико');
      expect(queues.scheduleOrderProcessing).toHaveBeenCalledWith(ORDER_ID);
      expect(result.id).toBe(ORDER_ID);
    });

    it('prefers the branch price override over base price', async () => {
      prisma.menuItem.findMany.mockResolvedValue([
        {
          id: MENU_ITEM_ID,
          name: 'Филадельфия',
          basePrice: D('400.00'),
          status: ProductStatus.PUBLISHED,
          prices: [{ price: D('450.00') }],
        },
      ]);
      await service.create(dto);
      const createArg = repository.create.mock.calls[0][0];
      // (450 + 50) * 2 = 1000
      expect(createArg.subtotalAmount.toString()).toBe('1000');
    });

    it('rejects an unavailable menu item with PRODUCT_UNAVAILABLE', async () => {
      prisma.menuItem.findMany.mockResolvedValue([]);
      await expect(service.create(dto)).rejects.toMatchObject({
        response: { code: 'PRODUCT_UNAVAILABLE' },
      });
      expect(repository.create).not.toHaveBeenCalled();
      expect(queues.scheduleOrderProcessing).not.toHaveBeenCalled();
    });

    it('rejects an inactive modifier with PRODUCT_UNAVAILABLE', async () => {
      prisma.modifierItem.findMany.mockResolvedValue([]);
      await expect(service.create(dto)).rejects.toMatchObject({
        response: { code: 'PRODUCT_UNAVAILABLE' },
      });
      expect(repository.create).not.toHaveBeenCalled();
    });

    it('does not touch loyalty when no bonuses are requested', async () => {
      await service.create(dto, CUSTOMER_ID);

      expect(loyalty.assertSpendAllowed).not.toHaveBeenCalled();
      expect(loyalty.spendWithinTransaction).not.toHaveBeenCalled();
      expect(prisma.$transaction).not.toHaveBeenCalled();
      const createArg = repository.create.mock.calls[0][0];
      expect(createArg.appliedBonusPoints).toBe(0);
      expect(createArg.bonusDiscountAmount.toString()).toBe('0');
    });
  });

  describe('create — bonus checkout (ADR-1614)', () => {
    const dto = {
      type: OrderType.DINE_IN,
      brandId: BRAND_ID,
      branchId: BRANCH_ID,
      tableNumber: '7',
      items: [
        {
          menuItemId: MENU_ITEM_ID,
          quantity: 2,
          modifiers: [{ modifierItemId: MODIFIER_ID, quantity: 1 }],
        },
      ],
      // Subtotal is 900 -> the 30% limit is 270 points.
      useBonusPoints: 200,
    };

    beforeEach(() => {
      prisma.menuItem.findMany.mockResolvedValue([
        {
          id: MENU_ITEM_ID,
          name: 'Филадельфия',
          basePrice: D('400.00'),
          status: ProductStatus.PUBLISHED,
          prices: [],
        },
      ]);
      prisma.modifierItem.findMany.mockResolvedValue([
        { id: MODIFIER_ID, name: 'Икра тобико', price: D('50.00') },
      ]);
      repository.create.mockResolvedValue({
        ...makeOrderRecord(),
        bonusDiscountAmount: D('200.00'),
        appliedBonusPoints: 200,
        totalAmount: D('700.00'),
      });
    });

    it('spends the points in one transaction with the order and reduces the payable total', async () => {
      const result = await service.create(dto, CUSTOMER_ID);

      // bonus_base = 900 (no promotion discounts yet); server-side guard.
      expect(loyalty.assertSpendAllowed).toHaveBeenCalledTimes(1);
      const guardArgs = loyalty.assertSpendAllowed.mock.calls[0];
      expect(guardArgs[0]).toBe(CUSTOMER_ID);
      expect(guardArgs[1]).toBe(200);
      expect(guardArgs[2].toString()).toBe('900');

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
      const createArg = repository.create.mock.calls[0][0];
      expect(createArg.subtotalAmount.toString()).toBe('900');
      expect(createArg.bonusDiscountAmount.toString()).toBe('200');
      expect(createArg.appliedBonusPoints).toBe(200);
      // payable = 900 - 200 = 700
      expect(createArg.totalAmount.toString()).toBe('700');
      expect(loyalty.spendWithinTransaction).toHaveBeenCalledWith(
        expect.anything(),
        { customerId: CUSTOMER_ID, orderId: ORDER_ID, points: 200 },
      );
      expect(queues.scheduleOrderProcessing).toHaveBeenCalledWith(ORDER_ID);
      expect(result.appliedBonusPoints).toBe(200);
      expect(result.bonusDiscountAmount).toBe(200);
      expect(result.totalAmount).toBe(700);
    });

    it('rejects bonus spend for an anonymous checkout with BONUS_CUSTOMER_REQUIRED', async () => {
      await expect(service.create(dto)).rejects.toMatchObject({
        response: { code: 'BONUS_CUSTOMER_REQUIRED' },
      });
      expect(loyalty.assertSpendAllowed).not.toHaveBeenCalled();
      expect(repository.create).not.toHaveBeenCalled();
      expect(queues.scheduleOrderProcessing).not.toHaveBeenCalled();
    });

    it('propagates the 30% limit rejection (422 BONUS_LIMIT_EXCEEDED) and writes nothing', async () => {
      loyalty.assertSpendAllowed.mockRejectedValue(
        new UnprocessableEntityException({
          statusCode: 422,
          code: 'BONUS_LIMIT_EXCEEDED',
          message: 'over the limit',
        }),
      );

      await expect(
        service.create({ ...dto, useBonusPoints: 500 }, CUSTOMER_ID),
      ).rejects.toMatchObject({ response: { code: 'BONUS_LIMIT_EXCEEDED' } });
      expect(repository.create).not.toHaveBeenCalled();
      expect(queues.scheduleOrderProcessing).not.toHaveBeenCalled();
    });

    it('rolls the order back when the balance raced (409 INSUFFICIENT_BONUS_BALANCE from the ledger)', async () => {
      loyalty.spendWithinTransaction.mockRejectedValue(
        new ConflictException({
          statusCode: 409,
          code: 'INSUFFICIENT_BONUS_BALANCE',
          message: 'balance moved',
        }),
      );

      await expect(service.create(dto, CUSTOMER_ID)).rejects.toMatchObject({
        response: { code: 'INSUFFICIENT_BONUS_BALANCE' },
      });
      expect(queues.scheduleOrderProcessing).not.toHaveBeenCalled();
    });
  });

  describe('updateStatus', () => {
    it('transitions and records history', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.NEW));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.CONFIRMED));

      const result = await service.updateStatus(ORDER_ID, {
        status: OrderStatus.CONFIRMED,
        changedBy: '88888888-8888-8888-8888-888888888888',
      });

      expect(repository.transitionStatus).toHaveBeenCalledWith(
        ORDER_ID,
        OrderStatus.NEW,
        OrderStatus.CONFIRMED,
        '88888888-8888-8888-8888-888888888888',
        undefined,
        undefined,
      );
      expect(result.status).toBe(OrderStatus.CONFIRMED);
    });

    it('emits a courier SSE event after transition', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.NEW));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.CONFIRMED));

      await service.updateStatus(ORDER_ID, { status: OrderStatus.CONFIRMED });

      expect(couriersEvents.emitOrderEvent).toHaveBeenCalledTimes(1);
      expect(couriersEvents.emitOrderEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          orderId: ORDER_ID,
          status: OrderStatus.CONFIRMED,
          branchId: BRANCH_ID,
        }),
      );
    });

    it('emits a customer tracking event after transition', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.NEW));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.CONFIRMED));

      await service.updateStatus(ORDER_ID, { status: OrderStatus.CONFIRMED });

      expect(couriersEvents.emitOrderTrackingEvent).toHaveBeenCalledTimes(1);
      const event = couriersEvents.emitOrderTrackingEvent.mock
        .calls[0][0] as OrderTrackingEvent;
      expect(event).toMatchObject({
        orderId: ORDER_ID,
        status: OrderStatus.CONFIRMED,
        courierId: null,
        version: 1,
        estimatedReadyAt: null,
      });
      expect(typeof event.timestamp).toBe('string');
    });

    it('emits a tracking event on cancellation', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.COOKING));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.CANCELLED));

      await service.updateStatus(ORDER_ID, {
        status: OrderStatus.CANCELLED,
        reason: 'out of ingredients',
      });

      expect(couriersEvents.emitOrderTrackingEvent).toHaveBeenCalledWith(
        expect.objectContaining({ orderId: ORDER_ID, status: OrderStatus.CANCELLED }),
      );
    });

    it('carries the assigned courier in the tracking event', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.READY));
      repository.transitionStatus.mockResolvedValue({
        ...makeOrderRecord(OrderStatus.ON_WAY),
        courierId: '99999999-9999-9999-9999-999999999999',
      });

      await service.updateStatus(ORDER_ID, {
        status: OrderStatus.ON_WAY,
        courierId: '99999999-9999-9999-9999-999999999999',
      });

      expect(couriersEvents.emitOrderTrackingEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          orderId: ORDER_ID,
          status: OrderStatus.ON_WAY,
          courierId: '99999999-9999-9999-9999-999999999999',
        }),
      );
    });

    it('does not emit a tracking event when the transition is rejected', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.COMPLETED));

      await expect(
        service.updateStatus(ORDER_ID, { status: OrderStatus.CANCELLED }),
      ).rejects.toBeInstanceOf(BadRequestException);

      expect(couriersEvents.emitOrderTrackingEvent).not.toHaveBeenCalled();
    });

    it('forwards courierId to the repository', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.READY));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.ON_WAY));

      await service.updateStatus(ORDER_ID, {
        status: OrderStatus.ON_WAY,
        courierId: '99999999-9999-9999-9999-999999999999',
      });

      expect(repository.transitionStatus).toHaveBeenCalledWith(
        ORDER_ID,
        OrderStatus.READY,
        OrderStatus.ON_WAY,
        undefined,
        undefined,
        '99999999-9999-9999-9999-999999999999',
      );
    });

    it('rejects invalid transitions with INVALID_ORDER_STATUS_TRANSITION', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.NEW));
      await expect(
        service.updateStatus(ORDER_ID, { status: OrderStatus.COMPLETED }),
      ).rejects.toMatchObject({
        response: { code: 'INVALID_ORDER_STATUS_TRANSITION' },
      });
      await expect(
        service.updateStatus(ORDER_ID, { status: OrderStatus.COMPLETED }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(repository.transitionStatus).not.toHaveBeenCalled();
    });

    it('rejects transitions out of terminal states', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.COMPLETED));
      await expect(
        service.updateStatus(ORDER_ID, { status: OrderStatus.CANCELLED }),
      ).rejects.toMatchObject({
        response: { code: 'INVALID_ORDER_STATUS_TRANSITION' },
      });
    });

    it('accrues cashback once the order reaches COMPLETED (ADR-1614)', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.READY));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.COMPLETED));

      await service.updateStatus(ORDER_ID, { status: OrderStatus.COMPLETED });

      expect(loyalty.earnCashback).toHaveBeenCalledWith(ORDER_ID);
      expect(loyalty.refundOnCancel).not.toHaveBeenCalled();
    });

    it('refunds the spent points when the order is CANCELLED (ADR-1614)', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.COOKING));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.CANCELLED));

      await service.updateStatus(ORDER_ID, {
        status: OrderStatus.CANCELLED,
        reason: 'out of ingredients',
      });

      expect(loyalty.refundOnCancel).toHaveBeenCalledWith(ORDER_ID);
      expect(loyalty.earnCashback).not.toHaveBeenCalled();
    });

    it('does not touch loyalty on non-terminal transitions', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.NEW));
      repository.transitionStatus.mockResolvedValue(makeOrderRecord(OrderStatus.CONFIRMED));

      await service.updateStatus(ORDER_ID, { status: OrderStatus.CONFIRMED });

      expect(loyalty.earnCashback).not.toHaveBeenCalled();
      expect(loyalty.refundOnCancel).not.toHaveBeenCalled();
    });

    it('throws ORDER_NOT_FOUND when missing', async () => {
      repository.findById.mockResolvedValue(null);
      await expect(
        service.updateStatus(ORDER_ID, { status: OrderStatus.CONFIRMED }),
      ).rejects.toMatchObject({ response: { code: 'ORDER_NOT_FOUND' } });
    });
  });

  describe('getTrackingStream', () => {
    it('emits the current state as the first (snapshot) event, then live events', async () => {
      repository.findById.mockResolvedValue(makeOrderRecord(OrderStatus.COOKING));
      const live: OrderTrackingEvent = {
        orderId: ORDER_ID,
        status: OrderStatus.READY,
        courierId: null,
        version: 2,
        estimatedReadyAt: null,
        timestamp: new Date().toISOString(),
      };
      couriersEvents.getOrderTrackingStream.mockReturnValue(of({ data: live }));

      const stream = await service.getTrackingStream(ORDER_ID, CUSTOMER_ID);
      const events = await firstValueFrom(stream.pipe(take(2), toArray()));

      expect(couriersEvents.getOrderTrackingStream).toHaveBeenCalledWith(ORDER_ID);
      expect(events).toHaveLength(2);
      expect(events[0].data).toMatchObject({
        orderId: ORDER_ID,
        status: OrderStatus.COOKING,
        version: 1,
      });
      expect(events[1].data).toEqual(live);
    });

    it('throws ORDER_NOT_FOUND when the order does not exist', async () => {
      repository.findById.mockResolvedValue(null);

      await expect(service.getTrackingStream(ORDER_ID, CUSTOMER_ID)).rejects.toMatchObject({
        response: { code: 'ORDER_NOT_FOUND' },
      });
      expect(couriersEvents.getOrderTrackingStream).not.toHaveBeenCalled();
    });

    it("throws ORDER_NOT_FOUND for a foreign customer's order", async () => {
      repository.findById.mockResolvedValue(makeOrderRecord());

      await expect(
        service.getTrackingStream(ORDER_ID, '00000000-0000-0000-0000-000000000000'),
      ).rejects.toMatchObject({ response: { code: 'ORDER_NOT_FOUND' } });
      expect(couriersEvents.getOrderTrackingStream).not.toHaveBeenCalled();
    });
  });
});
