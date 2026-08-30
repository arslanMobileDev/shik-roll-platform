import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { OrderStatus, OrderType, Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderQueuesService } from '../queues/order-queues.service';
import { OrdersRepository } from './orders.repository';
import { OrdersService } from './orders.service';

const D = (value: string | number) => new Prisma.Decimal(value);

const BRAND_ID = '11111111-1111-1111-1111-111111111111';
const BRANCH_ID = '22222222-2222-2222-2222-222222222222';
const MENU_ITEM_ID = '33333333-3333-3333-3333-333333333333';
const MODIFIER_ID = '44444444-4444-4444-4444-444444444444';
const ORDER_ID = '55555555-5555-5555-5555-555555555555';

function makeOrderRecord(status: OrderStatus = OrderStatus.NEW) {
  return {
    id: ORDER_ID,
    orderNumber: 'AAAA-20260830-0001',
    status,
    type: OrderType.DINE_IN,
    brandId: BRAND_ID,
    branchId: BRANCH_ID,
    tableNumber: '7',
    deliveryAddress: null,
    comment: null,
    subtotalAmount: D('800.00'),
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
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: OrdersRepository, useValue: repository },
        { provide: OrderQueuesService, useValue: queues },
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(OrdersService);
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
      );
      expect(result.status).toBe(OrderStatus.CONFIRMED);
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

    it('throws ORDER_NOT_FOUND when missing', async () => {
      repository.findById.mockResolvedValue(null);
      await expect(
        service.updateStatus(ORDER_ID, { status: OrderStatus.CONFIRMED }),
      ).rejects.toMatchObject({ response: { code: 'ORDER_NOT_FOUND' } });
    });
  });
});
