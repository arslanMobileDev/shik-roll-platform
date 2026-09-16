import * as bcrypt from 'bcryptjs';
import { JwtService } from '@nestjs/jwt';
import { OrderStatus } from '@prisma/client';
import { CouriersEventsService } from '../couriers/couriers-events.service';
import { OrdersEventsService } from '../orders/orders-events.service';
import { KitchenService } from './kitchen.service';
import { KitchenEventsService } from './kitchen-events.service';
import { AuthenticatedKitchenTerminal } from './kitchen.types';

const SECRET = 'kitchen-service-test-secret';

const TERMINAL_ROW = {
  id: 'terminal-1',
  code: 'KDS-01',
  name: 'Kitchen Terminal 1',
  branchId: 'branch-1',
  isActive: true,
};

const TERMINAL: AuthenticatedKitchenTerminal = {
  id: TERMINAL_ROW.id,
  code: TERMINAL_ROW.code,
  name: TERMINAL_ROW.name,
  branchId: TERMINAL_ROW.branchId,
  role: 'KITCHEN',
};

const ORDER_ID = '11111111-1111-1111-1111-111111111111';

function boardOrder(overrides: Record<string, unknown> = {}) {
  return {
    id: ORDER_ID,
    orderNumber: 'DEV-01-20260908-1',
    version: 3,
    status: OrderStatus.CONFIRMED,
    type: 'DELIVERY',
    courierId: null,
    estimatedReadyAt: null,
    totalAmount: 500,
    deliveryAddress: 'Delivery address',
    branchId: TERMINAL.branchId,
    tableNumber: null,
    comment: 'Без лука',
    confirmedAt: new Date('2026-09-08T10:00:00.000Z'),
    cookingStartedAt: null,
    readyAt: null,
    createdAt: new Date('2026-09-08T09:59:00.000Z'),
    items: [
      {
        id: 'item-1',
        name: 'Филадельфия',
        quantity: 2,
        comment: null,
        modifiers: [{ id: 'mod-1', name: 'Икра', quantity: 1 }],
      },
    ],
    ...overrides,
  };
}

describe('KitchenService', () => {
  let prisma: {
    kitchenTerminal: { findUnique: jest.Mock };
    branch: { findUnique: jest.Mock };
    order: {
      findFirst: jest.Mock;
      updateMany: jest.Mock;
      findUnique: jest.Mock;
      findUniqueOrThrow: jest.Mock;
    };
    orderStatusHistory: { create: jest.Mock };
    $transaction: jest.Mock;
  };
  let jwt: JwtService;
  let events: { publishOrderChanged: jest.Mock };
  let service: KitchenService;
  let courierEvents: CouriersEventsService;
  let orderEvents: OrdersEventsService;

  beforeEach(() => {
    prisma = {
      kitchenTerminal: { findUnique: jest.fn() },
      branch: { findUnique: jest.fn() },
      order: {
        findFirst: jest.fn(),
        updateMany: jest.fn(),
        findUnique: jest.fn(),
        findUniqueOrThrow: jest.fn(),
      },
      orderStatusHistory: { create: jest.fn().mockResolvedValue({}) },
      // Interactive transaction: run the callback against the same mocks.
      $transaction: jest
        .fn()
        .mockImplementation(async (cb: (tx: unknown) => unknown) => cb(prisma)),
    };
    jwt = new JwtService({ secret: SECRET });
    events = { publishOrderChanged: jest.fn().mockResolvedValue(undefined) };
    courierEvents = new CouriersEventsService();
    orderEvents = new OrdersEventsService();
    service = new KitchenService(
      prisma as never,
      jwt,
      events as unknown as KitchenEventsService,
      courierEvents,
      orderEvents,
    );
  });

  describe('authenticateByPin', () => {
    const dto = { terminalCode: 'KDS-01', pin: '1234' };

    beforeEach(() => {
      prisma.branch.findUnique.mockResolvedValue({ id: TERMINAL.branchId });
    });

    it('rejects an unknown terminal code with a uniform 401', async () => {
      prisma.kitchenTerminal.findUnique.mockResolvedValue(null);
      await expect(service.authenticateByPin(dto)).rejects.toMatchObject({
        response: { code: 'UNAUTHORIZED', message: 'Invalid terminal code or PIN' },
      });
    });

    it('rejects a wrong PIN with the same uniform 401', async () => {
      prisma.kitchenTerminal.findUnique.mockResolvedValue({
        ...TERMINAL_ROW,
        pinHash: bcrypt.hashSync('9999', 4),
      });
      await expect(service.authenticateByPin(dto)).rejects.toMatchObject({
        response: { code: 'UNAUTHORIZED' },
      });
    });

    it('rejects a deactivated terminal even with the right PIN', async () => {
      prisma.kitchenTerminal.findUnique.mockResolvedValue({
        ...TERMINAL_ROW,
        isActive: false,
        pinHash: bcrypt.hashSync(dto.pin, 4),
      });
      await expect(service.authenticateByPin(dto)).rejects.toMatchObject({
        response: { code: 'UNAUTHORIZED' },
      });
    });

    it('rejects a terminal whose branch is unavailable', async () => {
      prisma.kitchenTerminal.findUnique.mockResolvedValue({
        ...TERMINAL_ROW,
        pinHash: bcrypt.hashSync(dto.pin, 4),
      });
      prisma.branch.findUnique.mockResolvedValue(null);
      await expect(service.authenticateByPin(dto)).rejects.toMatchObject({
        response: { code: 'TERMINAL_BRANCH_UNAVAILABLE' },
      });
    });

    it('issues a KITCHEN access token scoped to the terminal branch', async () => {
      prisma.kitchenTerminal.findUnique.mockResolvedValue({
        ...TERMINAL_ROW,
        pinHash: bcrypt.hashSync(dto.pin, 4),
      });

      const result = await service.authenticateByPin(dto);

      expect(result.tokenType).toBe('Bearer');
      expect(result.expiresInSeconds).toBeGreaterThan(0);
      expect(result.terminal).toEqual({
        id: TERMINAL.id,
        code: TERMINAL.code,
        name: TERMINAL.name,
        branchId: TERMINAL.branchId,
      });
      const payload = await jwt.verifyAsync(result.token);
      expect(payload).toMatchObject({
        sub: TERMINAL.id,
        branchId: TERMINAL.branchId,
        role: 'KITCHEN',
        type: 'access',
      });
    });
  });

  describe('updateOrderStatus', () => {
    it.each(['COOKING', 'READY'] as const)(
      '%s reaches tracking, courier and both kitchen channels once after commit', async (status) => {
        const updated = boardOrder({ status, version: 4 });
        prisma.order.findFirst.mockResolvedValue(boardOrder({
          status: status === 'COOKING' ? OrderStatus.CONFIRMED : OrderStatus.COOKING,
        }));
        prisma.order.updateMany.mockResolvedValue({ count: 1 });
        prisma.order.findUniqueOrThrow.mockResolvedValue(updated);
        let committed = false;
        prisma.$transaction.mockImplementation(async (cb) => {
          const result = await cb(prisma);
          committed = true;
          return result;
        });
        const tracking: MessageEvent[] = [];
        const courier: MessageEvent[] = [];
        const legacy: MessageEvent[] = [];
        const foreign: MessageEvent[] = [];
        const subscriptions = [
          courierEvents.getOrderTrackingStream(ORDER_ID).subscribe(e => {
            expect(committed).toBe(true); tracking.push(e);
          }),
          courierEvents.getOrderStream(TERMINAL.branchId).subscribe(e => courier.push(e)),
          orderEvents.getKdsStream(TERMINAL.branchId).subscribe(e => legacy.push(e)),
          courierEvents.getOrderTrackingStream('other-order').subscribe(e => foreign.push(e)),
          courierEvents.getOrderStream('other-branch').subscribe(e => foreign.push(e)),
        ];
        try {
          await service.updateOrderStatus(TERMINAL, ORDER_ID, { status, expectedVersion: 3 });
          expect(tracking).toHaveLength(1);
          expect(tracking[0].data).toMatchObject({ orderId: ORDER_ID, status, version: 4 });
          expect(courier).toHaveLength(1);
          expect(courier[0].data).toMatchObject({ orderId: ORDER_ID, status, branchId: TERMINAL.branchId });
          expect(legacy).toHaveLength(1);
          expect(legacy[0].data).toMatchObject({ eventType: 'ORDER_STATUS_CHANGED', status });
          expect(events.publishOrderChanged).toHaveBeenCalledTimes(1);
          expect(foreign).toHaveLength(0);
        } finally { subscriptions.forEach(s => s.unsubscribe()); }
      },
    );

    it('does not send takeaway orders to the courier feed', async () => {
      prisma.order.findFirst.mockResolvedValue(boardOrder({ status: OrderStatus.COOKING }));
      prisma.order.updateMany.mockResolvedValue({ count: 1 });
      prisma.order.findUniqueOrThrow.mockResolvedValue(boardOrder({ status: OrderStatus.READY, type: 'TAKEAWAY' }));
      const publish = jest.spyOn(courierEvents, 'emitOrderEvent');
      const tracking = jest.spyOn(courierEvents, 'emitOrderTrackingEvent');
      await service.updateOrderStatus(TERMINAL, ORDER_ID, { status: 'READY', expectedVersion: 3 });
      expect(publish).not.toHaveBeenCalled();
      expect(tracking).toHaveBeenCalledTimes(1);
      expect(events.publishOrderChanged).toHaveBeenCalledTimes(1);
    });

    it('publishes nothing if the transaction rolls back', async () => {
      prisma.order.findFirst.mockResolvedValue(boardOrder());
      prisma.$transaction.mockRejectedValue(new Error('rollback'));
      const tracking = jest.spyOn(courierEvents, 'emitOrderTrackingEvent');
      const courier = jest.spyOn(courierEvents, 'emitOrderEvent');
      const legacy = jest.spyOn(orderEvents, 'emitKdsEvent');
      await expect(service.updateOrderStatus(TERMINAL, ORDER_ID, {
        status: 'COOKING', expectedVersion: 3,
      })).rejects.toThrow('rollback');
      expect(tracking).not.toHaveBeenCalled();
      expect(courier).not.toHaveBeenCalled();
      expect(legacy).not.toHaveBeenCalled();
      expect(events.publishOrderChanged).not.toHaveBeenCalled();
    });

    it('answers 404 ORDER_NOT_FOUND for an unknown order', async () => {
      prisma.order.findFirst.mockResolvedValue(null);
      await expect(
        service.updateOrderStatus(TERMINAL, ORDER_ID, {
          status: 'COOKING',
          expectedVersion: 3,
        }),
      ).rejects.toMatchObject({ response: { code: 'ORDER_NOT_FOUND' } });
    });

    it('answers 403 ORDER_BRANCH_FORBIDDEN for a foreign-branch order', async () => {
      prisma.order.findFirst.mockResolvedValue(
        boardOrder({ branchId: 'branch-2' }),
      );
      await expect(
        service.updateOrderStatus(TERMINAL, ORDER_ID, {
          status: 'COOKING',
          expectedVersion: 3,
        }),
      ).rejects.toMatchObject({ response: { code: 'ORDER_BRANCH_FORBIDDEN' } });
    });

    it('answers 409 INVALID_ORDER_STATUS_TRANSITION when the order is not in the source status', async () => {
      prisma.order.findFirst.mockResolvedValue(
        boardOrder({ status: OrderStatus.READY }),
      );
      await expect(
        service.updateOrderStatus(TERMINAL, ORDER_ID, {
          status: 'COOKING',
          expectedVersion: 3,
        }),
      ).rejects.toMatchObject({
        response: { code: 'INVALID_ORDER_STATUS_TRANSITION' },
      });
    });

    it('answers 409 INVALID_ORDER_STATUS_TRANSITION for a skipped step (CONFIRMED -> READY)', async () => {
      prisma.order.findFirst.mockResolvedValue(boardOrder());
      await expect(
        service.updateOrderStatus(TERMINAL, ORDER_ID, {
          status: 'READY',
          expectedVersion: 3,
        }),
      ).rejects.toMatchObject({
        response: { code: 'INVALID_ORDER_STATUS_TRANSITION' },
      });
    });

    it('answers 409 ORDER_VERSION_CONFLICT on a stale expectedVersion', async () => {
      prisma.order.findFirst.mockResolvedValue(boardOrder());
      prisma.order.updateMany.mockResolvedValue({ count: 0 });
      // The concurrent re-read still shows the source status -> it is the
      // version that lost the race.
      prisma.order.findUnique.mockResolvedValue({ status: OrderStatus.CONFIRMED });

      await expect(
        service.updateOrderStatus(TERMINAL, ORDER_ID, {
          status: 'COOKING',
          expectedVersion: 2,
        }),
      ).rejects.toMatchObject({ response: { code: 'ORDER_VERSION_CONFLICT' } });
    });

    it('answers 409 INVALID_ORDER_STATUS_TRANSITION when the lost race moved the status', async () => {
      prisma.order.findFirst.mockResolvedValue(boardOrder());
      prisma.order.updateMany.mockResolvedValue({ count: 0 });
      prisma.order.findUnique.mockResolvedValue({ status: OrderStatus.COOKING });

      await expect(
        service.updateOrderStatus(TERMINAL, ORDER_ID, {
          status: 'COOKING',
          expectedVersion: 3,
        }),
      ).rejects.toMatchObject({
        response: { code: 'INVALID_ORDER_STATUS_TRANSITION' },
      });
    });

    it('records verified attribution and rejects a closed shift before mutation', async () => {
      prisma.order.findFirst.mockResolvedValue(boardOrder());
      prisma.order.updateMany.mockResolvedValue({count:1});
      prisma.order.findUniqueOrThrow.mockResolvedValue(boardOrder({status:OrderStatus.COOKING}));
      const query=jest.fn().mockResolvedValue([{id:'shift'}]);
      (prisma as any).$queryRaw=query;
      const actor={id:'cook',shiftId:'shift',terminalId:TERMINAL.id,branchId:TERMINAL.branchId};
      await service.updateOrderStatus(TERMINAL,ORDER_ID,{status:'COOKING',expectedVersion:3,cookId:'forged'},actor);
      expect(prisma.orderStatusHistory.create).toHaveBeenCalledWith({data:expect.objectContaining({cookId:'cook',shiftId:'shift'})});
      prisma.order.updateMany.mockClear();query.mockResolvedValue([]);
      await expect(service.updateOrderStatus(TERMINAL,ORDER_ID,{status:'COOKING',expectedVersion:3},actor)).rejects.toThrow();
      expect(prisma.order.updateMany).not.toHaveBeenCalled();
    });

    it('moves CONFIRMED -> COOKING atomically with server timestamp, audit and board publish', async () => {
      const updated = boardOrder({
        status: OrderStatus.COOKING,
        version: 4,
        cookingStartedAt: new Date('2026-09-08T10:05:00.000Z'),
      });
      prisma.order.findFirst.mockResolvedValue(boardOrder());
      prisma.order.updateMany.mockResolvedValue({ count: 1 });
      prisma.order.findUniqueOrThrow.mockResolvedValue(updated);

      const result = await service.updateOrderStatus(TERMINAL, ORDER_ID, {
        status: 'COOKING',
        expectedVersion: 3,
        cookId: 'cook-7',
        shiftId: 'shift-9',
      });

      expect(prisma.order.updateMany).toHaveBeenCalledWith({
        where: {
          id: ORDER_ID,
          branchId: TERMINAL.branchId,
          status: OrderStatus.CONFIRMED,
          version: 3,
        },
        data: {
          status: OrderStatus.COOKING,
          version: { increment: 1 },
          cookingStartedAt: expect.any(Date),
        },
      });
      expect(prisma.orderStatusHistory.create).toHaveBeenCalledWith({
        data: {
          orderId: ORDER_ID,
          previousStatus: OrderStatus.CONFIRMED,
          newStatus: OrderStatus.COOKING,
          kitchenTerminalId: TERMINAL.id,
          cookId: null,
          shiftId: null,
        },
      });
      expect(events.publishOrderChanged).toHaveBeenCalledWith(ORDER_ID);
      expect(result).toMatchObject({
        id: ORDER_ID,
        status: 'COOKING',
        version: 4,
        cookingStartedAt: '2026-09-08T10:05:00.000Z',
      });
      // The board projection never leaks customer/payment data.
      expect(result).not.toHaveProperty('totalAmount');
      expect(result).not.toHaveProperty('customerId');
      expect(result).not.toHaveProperty('deliveryAddress');
    });

    it('stamps confirmedAt when COOKING starts from NEW (ADR-1618)', async () => {
      // ON_DELIVERY orders skip the explicit CONFIRMED step on the kitchen
      // board: the operator starts cooking straight from NEW. The data
      // contract still requires confirmedAt to be written.
      prisma.order.findFirst.mockResolvedValue(
        boardOrder({ status: OrderStatus.NEW, confirmedAt: null }),
      );
      prisma.order.updateMany.mockResolvedValue({ count: 1 });
      prisma.order.findUniqueOrThrow.mockResolvedValue(
        boardOrder({
          status: OrderStatus.COOKING,
          version: 4,
          cookingStartedAt: new Date('2026-09-08T10:05:00.000Z'),
          confirmedAt: new Date('2026-09-08T10:05:00.000Z'),
        }),
      );

      await service.updateOrderStatus(TERMINAL, ORDER_ID, {
        status: 'COOKING',
        expectedVersion: 3,
      });

      expect(prisma.order.updateMany).toHaveBeenCalledWith({
        where: {
          id: ORDER_ID,
          branchId: TERMINAL.branchId,
          status: OrderStatus.NEW,
          version: 3,
        },
        data: {
          status: OrderStatus.COOKING,
          version: { increment: 1 },
          cookingStartedAt: expect.any(Date),
          confirmedAt: expect.any(Date),
        },
      });
    });

    it('does not overwrite confirmedAt on CONFIRMED -> COOKING', async () => {
      const originalConfirmedAt = new Date('2026-09-08T10:00:00.000Z');
      prisma.order.findFirst.mockResolvedValue(
        boardOrder({ status: OrderStatus.CONFIRMED, confirmedAt: originalConfirmedAt }),
      );
      prisma.order.updateMany.mockResolvedValue({ count: 1 });
      prisma.order.findUniqueOrThrow.mockResolvedValue(
        boardOrder({
          status: OrderStatus.COOKING,
          version: 4,
          cookingStartedAt: new Date('2026-09-08T10:05:00.000Z'),
          confirmedAt: originalConfirmedAt,
        }),
      );

      await service.updateOrderStatus(TERMINAL, ORDER_ID, {
        status: 'COOKING',
        expectedVersion: 3,
      });

      const call = prisma.order.updateMany.mock.calls[0][0];
      expect(call.data).not.toHaveProperty('confirmedAt');
    });

    it('moves COOKING -> READY stamping readyAt', async () => {
      const cooking = boardOrder({
        status: OrderStatus.COOKING,
        cookingStartedAt: new Date('2026-09-08T10:05:00.000Z'),
      });
      const ready = boardOrder({
        status: OrderStatus.READY,
        version: 4,
        cookingStartedAt: new Date('2026-09-08T10:05:00.000Z'),
        readyAt: new Date('2026-09-08T10:20:00.000Z'),
      });
      prisma.order.findFirst.mockResolvedValue(cooking);
      prisma.order.updateMany.mockResolvedValue({ count: 1 });
      prisma.order.findUniqueOrThrow.mockResolvedValue(ready);

      const result = await service.updateOrderStatus(TERMINAL, ORDER_ID, {
        status: 'READY',
        expectedVersion: 3,
      });

      expect(prisma.order.updateMany).toHaveBeenCalledWith({
        where: {
          id: ORDER_ID,
          branchId: TERMINAL.branchId,
          status: OrderStatus.COOKING,
          version: 3,
        },
        data: {
          status: OrderStatus.READY,
          version: { increment: 1 },
          readyAt: expect.any(Date),
        },
      });
      expect(result).toMatchObject({
        status: 'READY',
        readyAt: '2026-09-08T10:20:00.000Z',
      });
      expect(events.publishOrderChanged).toHaveBeenCalledWith(ORDER_ID);
    });
  });
});
