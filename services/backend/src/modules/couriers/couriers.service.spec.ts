import * as bcrypt from 'bcryptjs';
import {
  ConflictException,
  ForbiddenException,
  HttpException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OrderStatus, OrderType } from '@prisma/client';
import { CouriersService } from './couriers.service';
import { COURIER_TOKEN_TTL_SECONDS } from './couriers.config';
import { AuthenticatedCourier, CourierTokenPayload } from './couriers.types';

const SECRET = 'courier-service-test-secret';

function prismaMock() {
  return {
    courier: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
    branch: { findFirst: jest.fn() },
    brand: { findFirst: jest.fn() },
    order: {
      findUnique: jest.fn(),
      findUniqueOrThrow: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
  };
}

function eventsMock() {
  return {
    emitOrderEvent: jest.fn(),
    emitOrderTrackingEvent: jest.fn(),
    emitCourierLocation: jest.fn(),
  };
}

function loyaltyMock() {
  return { earnCashback: jest.fn(), refundOnCancel: jest.fn() };
}

const existingCourier = {
  id: 'courier-1',
  name: 'Курьер 4567',
  phone: '+79991234567',
  pinHash: '',
  brandId: 'brand-1',
  branchId: 'branch-1',
  isAvailable: true,
  createdAt: new Date(),
  updatedAt: new Date(),
};

const jwtCourier: AuthenticatedCourier = {
  id: 'courier-1',
  phone: '+79991234567',
  branchId: 'branch-1',
  role: 'COURIER',
};

function makeOrder(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    id: 'order-1',
    orderNumber: 'A-1001',
    status: OrderStatus.READY,
    type: OrderType.DELIVERY,
    brandId: 'brand-1',
    branchId: 'branch-1',
    courierId: null,
    deliveryAddress: 'ул. Баумана, 58',
    comment: null,
    totalAmount: 1250,
    estimatedReadyAt: null,
    completedAt: null,
    version: 3,
    createdAt: new Date('2026-09-08T12:05:00Z'),
    customer: { phone: '+79171234567' },
    ...overrides,
  } as any;
}

describe('CouriersService.authenticateByPin', () => {
  let prisma: ReturnType<typeof prismaMock>;
  let jwt: JwtService;
  let service: CouriersService;

  beforeEach(() => {
    prisma = prismaMock();
    jwt = new JwtService({ secret: SECRET });
    service = new CouriersService(prisma as any, jwt, eventsMock() as any, loyaltyMock() as any);
  });

  it('registers a new courier with a bcrypt-hashed PIN and returns a signed JWT', async () => {
    prisma.courier.findUnique.mockResolvedValue(null);
    prisma.branch.findFirst.mockResolvedValue({ id: 'branch-1' });
    prisma.brand.findFirst.mockResolvedValue({ id: 'brand-1' });
    prisma.courier.create.mockImplementation(async ({ data }) => ({
      ...existingCourier,
      ...data,
    }));

    const result = await service.authenticateByPin({
      phone: existingCourier.phone,
      pin: '1234',
    });

    // PIN is stored only as a bcrypt hash, never in plaintext.
    const { pinHash } = prisma.courier.create.mock.calls[0][0].data;
    expect(pinHash).toMatch(/^\$2[aby]\$/);
    expect(pinHash).not.toBe('1234');
    await expect(bcrypt.compare('1234', pinHash)).resolves.toBe(true);
    await expect(bcrypt.compare('9999', pinHash)).resolves.toBe(false);

    // The token is a real signed JWT carrying courierId, branch and role.
    expect(result.token).not.toContain('courier-session-');
    expect(result.tokenType).toBe('Bearer');
    expect(result.expiresInSeconds).toBe(COURIER_TOKEN_TTL_SECONDS);

    const payload = await jwt.verifyAsync<CourierTokenPayload & { iat: number; exp: number }>(
      result.token,
    );
    expect(payload.sub).toBe(existingCourier.id);
    expect(payload.phone).toBe(existingCourier.phone);
    expect(payload.branchId).toBe('branch-1');
    expect(payload.role).toBe('COURIER');
    expect(payload.type).toBe('access');
    expect(payload.exp - payload.iat).toBe(COURIER_TOKEN_TTL_SECONDS);
  });

  it('authenticates an existing courier with the correct PIN', async () => {
    const pinHash = await bcrypt.hash('1234', 4);
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash });

    const result = await service.authenticateByPin({
      phone: existingCourier.phone,
      pin: '1234',
    });

    const payload = await jwt.verifyAsync<CourierTokenPayload>(result.token);
    expect(payload.sub).toBe('courier-1');
    expect(payload.branchId).toBe('branch-1');
    expect(prisma.courier.update).not.toHaveBeenCalled();
  });

  it('rejects a wrong PIN with UnauthorizedException', async () => {
    const pinHash = await bcrypt.hash('1234', 4);
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash });

    await expect(
      service.authenticateByPin({ phone: existingCourier.phone, pin: '9999' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('migrates a legacy plaintext pinHash to bcrypt on successful login', async () => {
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash: '1234' });

    const result = await service.authenticateByPin({
      phone: existingCourier.phone,
      pin: '1234',
    });

    expect(result.token).toBeDefined();
    expect(prisma.courier.update).toHaveBeenCalledTimes(1);
    const updateArgs = prisma.courier.update.mock.calls[0][0];
    expect(updateArgs.where).toEqual({ id: 'courier-1' });
    expect(updateArgs.data.pinHash).toMatch(/^\$2[aby]\$/);
    await expect(bcrypt.compare('1234', updateArgs.data.pinHash)).resolves.toBe(true);
  });

  it('rejects a wrong PIN on a legacy plaintext row without migrating it', async () => {
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash: '1234' });

    await expect(
      service.authenticateByPin({ phone: existingCourier.phone, pin: '9999' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.courier.update).not.toHaveBeenCalled();
  });

  it('fails registration when branch/brand configuration is missing', async () => {
    prisma.courier.findUnique.mockResolvedValue(null);
    prisma.branch.findFirst.mockResolvedValue(null);
    prisma.brand.findFirst.mockResolvedValue({ id: 'brand-1' });

    await expect(
      service.authenticateByPin({ phone: '+79990000000', pin: '1234' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.courier.create).not.toHaveBeenCalled();
  });
});

describe('CouriersService.getActiveOrders', () => {
  let prisma: ReturnType<typeof prismaMock>;
  let service: CouriersService;

  beforeEach(() => {
    prisma = prismaMock();
    service = new CouriersService(
      prisma as any,
      new JwtService({ secret: SECRET }),
      eventsMock() as any,
      loyaltyMock() as any,
    );
  });

  it('scopes the feed to the JWT branch and unassigned/own orders', async () => {
    prisma.order.findMany.mockResolvedValue([makeOrder()]);

    const result = await service.getActiveOrders('branch-1', 'courier-1');

    expect(prisma.order.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          branchId: 'branch-1',
          OR: [{ courierId: null }, { courierId: 'courier-1' }],
        }),
      }),
    );
    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      id: 'order-1',
      number: 'A-1001',
      status: OrderStatus.READY,
      clientPhone: '+79171234567',
    });
  });
});

describe('CouriersService.updateCourierOrderStatus', () => {
  let prisma: ReturnType<typeof prismaMock>;
  let events: ReturnType<typeof eventsMock>;
  let loyalty: ReturnType<typeof loyaltyMock>;
  let service: CouriersService;

  beforeEach(() => {
    prisma = prismaMock();
    events = eventsMock();
    loyalty = loyaltyMock();
    service = new CouriersService(
      prisma as any,
      new JwtService({ secret: SECRET }),
      events as any,
      loyalty as any,
    );
  });

  it('claims an unassigned READY order atomically and emits events', async () => {
    const order = makeOrder();
    prisma.order.findUnique.mockResolvedValue(order);
    prisma.order.count.mockResolvedValue(0);
    prisma.order.updateMany.mockResolvedValue({ count: 1 });
    const claimed = makeOrder({ courierId: 'courier-1', version: 4 });
    prisma.order.findUniqueOrThrow.mockResolvedValue(claimed);

    const result = await service.updateCourierOrderStatus(jwtCourier, 'order-1', {
      status: 'READY',
    });

    expect(prisma.order.updateMany).toHaveBeenCalledWith({
      where: { id: 'order-1', status: OrderStatus.READY, courierId: null },
      data: { courierId: 'courier-1', version: { increment: 1 } },
    });
    expect(result.courierId).toBe('courier-1');
    expect(events.emitOrderEvent).toHaveBeenCalledWith(
      expect.objectContaining({ orderId: 'order-1', courierId: 'courier-1' }),
    );
    expect(events.emitOrderTrackingEvent).toHaveBeenCalledWith(
      expect.objectContaining({ orderId: 'order-1', version: 4 }),
    );
    expect(loyalty.earnCashback).not.toHaveBeenCalled();
  });

  it('rejects the claim when the courier already has an active order', async () => {
    prisma.order.findUnique.mockResolvedValue(makeOrder());
    prisma.order.count.mockResolvedValue(1);

    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'order-1', { status: 'READY' }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'COURIER_HAS_ACTIVE_ORDER' }),
    });
    expect(prisma.order.updateMany).not.toHaveBeenCalled();
  });

  it('rejects the claim of an already assigned order', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-2' }),
    );

    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'order-1', { status: 'READY' }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'ORDER_ALREADY_ASSIGNED' }),
    });
  });

  it('rejects the claim of a COOKING order as an invalid transition', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ status: OrderStatus.COOKING }),
    );
    prisma.order.count.mockResolvedValue(0);

    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'order-1', { status: 'READY' }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        code: 'INVALID_ORDER_STATUS_TRANSITION',
      }),
    });
  });

  it('maps a lost claim race (updateMany count 0) to ORDER_ALREADY_ASSIGNED', async () => {
    prisma.order.findUnique.mockResolvedValue(makeOrder());
    prisma.order.count.mockResolvedValue(0);
    prisma.order.updateMany.mockResolvedValue({ count: 0 });

    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'order-1', { status: 'READY' }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'ORDER_ALREADY_ASSIGNED' }),
    });
  });

  it('starts the delivery of the courier\'s own READY order', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-1' }),
    );
    prisma.order.updateMany.mockResolvedValue({ count: 1 });
    prisma.order.findUniqueOrThrow.mockResolvedValue(
      makeOrder({ courierId: 'courier-1', status: OrderStatus.ON_WAY, version: 4 }),
    );

    const result = await service.updateCourierOrderStatus(jwtCourier, 'order-1', {
      status: 'ON_WAY',
    });

    expect(prisma.order.updateMany).toHaveBeenCalledWith({
      where: { id: 'order-1', status: OrderStatus.READY, courierId: 'courier-1' },
      data: { status: OrderStatus.ON_WAY, version: { increment: 1 } },
    });
    expect(result.status).toBe(OrderStatus.ON_WAY);
  });

  it('rejects starting a foreign order with ORDER_NOT_ASSIGNED_TO_COURIER', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-2' }),
    );

    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'order-1', { status: 'ON_WAY' }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        code: 'ORDER_NOT_ASSIGNED_TO_COURIER',
      }),
    });
    expect(prisma.order.updateMany).not.toHaveBeenCalled();
  });

  it('completes the courier\'s own ON_WAY order and earns cashback once', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-1', status: OrderStatus.ON_WAY }),
    );
    prisma.order.updateMany.mockResolvedValue({ count: 1 });
    prisma.order.findUniqueOrThrow.mockResolvedValue(
      makeOrder({
        courierId: 'courier-1',
        status: OrderStatus.COMPLETED,
        completedAt: new Date(),
        version: 5,
      }),
    );

    const result = await service.updateCourierOrderStatus(jwtCourier, 'order-1', {
      status: 'COMPLETED',
    });

    expect(result.status).toBe(OrderStatus.COMPLETED);
    expect(prisma.order.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: OrderStatus.COMPLETED,
          completedAt: expect.any(Date),
        }),
      }),
    );
    expect(loyalty.earnCashback).toHaveBeenCalledWith('order-1');
  });

  it('rejects completing a READY order as an invalid transition', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-1' }),
    );

    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'order-1', {
        status: 'COMPLETED',
      }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        code: 'INVALID_ORDER_STATUS_TRANSITION',
      }),
    });
    expect(loyalty.earnCashback).not.toHaveBeenCalled();
  });

  it('hides orders of other branches behind ORDER_NOT_FOUND', async () => {
    prisma.order.findUnique.mockResolvedValue(makeOrder({ branchId: 'branch-2' }));

    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'order-1', { status: 'READY' }),
    ).rejects.toBeInstanceOf(NotFoundException);

    prisma.order.findUnique.mockResolvedValue(null);
    await expect(
      service.updateCourierOrderStatus(jwtCourier, 'missing', { status: 'READY' }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'ORDER_NOT_FOUND' }),
    });
  });
});

describe('CouriersService.reportCourierLocation', () => {
  let prisma: ReturnType<typeof prismaMock>;
  let events: ReturnType<typeof eventsMock>;
  let service: CouriersService;

  const dto = {
    orderId: 'order-1',
    latitude: 55.7893,
    longitude: 49.1221,
    accuracyMeters: 12,
    capturedAt: () => new Date().toISOString(),
  };

  beforeEach(() => {
    prisma = prismaMock();
    events = eventsMock();
    service = new CouriersService(
      prisma as any,
      new JwtService({ secret: SECRET }),
      events as any,
      loyaltyMock() as any,
    );
  });

  it('accepts a fix for the courier\'s own ON_WAY order and publishes it', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-1', status: OrderStatus.ON_WAY }),
    );

    const result = await service.reportCourierLocation(jwtCourier, {
      ...dto,
      capturedAt: dto.capturedAt(),
    });

    expect(result).toEqual({ accepted: true });
    expect(events.emitCourierLocation).toHaveBeenCalledWith(
      expect.objectContaining({
        orderId: 'order-1',
        courierId: 'courier-1',
        branchId: 'branch-1',
        latitude: 55.7893,
        longitude: 49.1221,
      }),
    );
  });

  it('rejects a fix for a foreign order', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-2', status: OrderStatus.ON_WAY }),
    );

    await expect(
      service.reportCourierLocation(jwtCourier, {
        ...dto,
        capturedAt: dto.capturedAt(),
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(events.emitCourierLocation).not.toHaveBeenCalled();
  });

  it('rejects a fix when the order is not ON_WAY', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-1', status: OrderStatus.READY }),
    );

    await expect(
      service.reportCourierLocation(jwtCourier, {
        ...dto,
        capturedAt: dto.capturedAt(),
      }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'ORDER_NOT_ON_WAY' }),
    });
  });

  it('rejects fixes outside the allowed clock skew', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-1', status: OrderStatus.ON_WAY }),
    );
    const stale = new Date(Date.now() - 30 * 60 * 1000).toISOString();

    await expect(
      service.reportCourierLocation(jwtCourier, { ...dto, capturedAt: stale }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'LOCATION_CLOCK_SKEW' }),
    });
  });

  it('rate-limits fixes that arrive faster than the minimum interval', async () => {
    prisma.order.findUnique.mockResolvedValue(
      makeOrder({ courierId: 'courier-1', status: OrderStatus.ON_WAY }),
    );

    await service.reportCourierLocation(jwtCourier, {
      ...dto,
      capturedAt: dto.capturedAt(),
    });

    let error: unknown;
    try {
      await service.reportCourierLocation(jwtCourier, {
        ...dto,
        capturedAt: dto.capturedAt(),
      });
    } catch (e) {
      error = e;
    }
    expect(error).toBeInstanceOf(HttpException);
    expect((error as HttpException).getStatus()).toBe(429);
    expect((error as HttpException).getResponse()).toMatchObject({
      code: 'LOCATION_RATE_LIMITED',
    });
  });

  it('hides orders of other branches behind ORDER_NOT_FOUND', async () => {
    prisma.order.findUnique.mockResolvedValue(makeOrder({ branchId: 'branch-2' }));

    await expect(
      service.reportCourierLocation(jwtCourier, {
        ...dto,
        capturedAt: dto.capturedAt(),
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
