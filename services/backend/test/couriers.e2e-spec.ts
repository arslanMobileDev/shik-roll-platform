import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { INestApplication, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { OrderStatus, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import request from 'supertest';
import { AppModule } from '../src/app.module';

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';

process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.DISABLE_QUEUES = 'true';

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

async function truncateAll(): Promise<void> {
  await prisma.payment.deleteMany();
  await prisma.orderStatusHistory.deleteMany();
  await prisma.orderItemModifier.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.courier.deleteMany();
  await prisma.kitchenTerminal.deleteMany();
  await prisma.cookShift.deleteMany();
  await prisma.stopListEntry.deleteMany();
  await prisma.branchMenuItemAvailability.deleteMany();
  await prisma.menuItemPrice.deleteMany();
  await prisma.menuItemCertification.deleteMany();
  await prisma.certificationTag.deleteMany();
  await prisma.menuItemIngredient.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.menuItemModifierGroup.deleteMany();
  await prisma.modifierItem.deleteMany();
  await prisma.modifierGroup.deleteMany();
  await prisma.menuItem.deleteMany();
  await prisma.category.deleteMany();
  await prisma.menu.deleteMany();
  await prisma.orderSequence.deleteMany();
  await prisma.brandBranch.deleteMany();
  await prisma.branch.deleteMany();
  await prisma.staff.deleteMany();
  await prisma.brand.deleteMany();
}

interface Fixture {
  brandId: string;
  branchId: string;
  courierId: string;
  courierPhone: string;
  courierPin: string;
}

async function seedFixtures(): Promise<Fixture> {
  const brand = await prisma.brand.create({
    data: { code: 'COURIER_E2E', name: 'Courier E2E' },
  });
  const branch = await prisma.branch.create({
    data: { code: 'C-E2E-01', name: 'Courier E2E Branch' },
  });
  await prisma.brandBranch.create({
    data: { brandId: brand.id, branchId: branch.id },
  });

  const courierPhone = '+79995550001';
  const courierPin = '1234';
  const courier = await prisma.courier.create({
    data: {
      name: 'Courier E2E',
      phone: courierPhone,
      pinHash: await bcrypt.hash(courierPin, 4),
      brandId: brand.id,
      branchId: branch.id,
      isActive: true,
      isAvailable: true,
    },
  });

  return {
    brandId: brand.id,
    branchId: branch.id,
    courierId: courier.id,
    courierPhone,
    courierPin,
  };
}

describe('Couriers API (e2e)', () => {
  let app: INestApplication;
  let fx: Fixture;
  let courierToken: string;

  beforeAll(async () => {
    execSync('pnpm prisma migrate deploy', {
      cwd: path.resolve(__dirname, '..'),
      env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
      stdio: 'inherit',
    });
    await truncateAll();
    fx = await seedFixtures();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        exceptionFactory: (errors) =>
          new BadRequestException({
            statusCode: 400,
            code: 'VALIDATION_ERROR',
            message: errors
              .map((e) => Object.values(e.constraints ?? {}).join(', '))
              .filter(Boolean)
              .join('; '),
          }),
      }),
    );
    await app.init();

    const login = await request(app.getHttpServer())
      .post('/couriers/auth/pin')
      .send({ phone: fx.courierPhone, pin: fx.courierPin })
      .expect(201);
    courierToken = login.body.token;
  });

  afterAll(async () => {
    await app?.close();
    await prisma.$disconnect();
  });

  /**
   * Each test starts with a clean order slate. The seeded courier is reused
   * (login happens once in beforeAll) but must not carry an active delivery
   * across tests — otherwise claim-testing scenarios bleed into each other.
   */
  beforeEach(async () => {
    await prisma.orderStatusHistory.deleteMany();
    await prisma.orderItemModifier.deleteMany();
    await prisma.orderItem.deleteMany();
    await prisma.order.deleteMany();
  });

  const http = () => request(app.getHttpServer());

  /**
   * Creates an order directly via Prisma in the requested status.
   * POST /orders always produces PENDING_PAYMENT or NEW, and the courier
   * API only accepts pre-READY delivery orders, so direct insertion keeps
   * the tests focused on the courier contract.
   */
  const createOrderInStatus = async (
    status: OrderStatus,
    options: { courierId?: string | null } = {},
  ): Promise<string> => {
    const order = await prisma.order.create({
      data: {
        brandId: fx.brandId,
        branchId: fx.branchId,
        type: 'DELIVERY',
        status,
        orderNumber: `E2E-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`,
        subtotalAmount: 100,
        totalAmount: 100,
        currency: 'RUB',
        courierId: options.courierId ?? null,
      },
    });
    return order.id;
  };

  const getOrderState = async (id: string) => {
    const o = await prisma.order.findUniqueOrThrow({ where: { id } });
    return { status: o.status, version: o.version, courierId: o.courierId, completedAt: o.completedAt };
  };

  const patchStatus = (id: string, status: 'READY' | 'ON_WAY' | 'COMPLETED', token?: string) => {
    const req = http().patch(`/couriers/orders/${id}/status`).send({ status });
    if (token) req.set('Authorization', `Bearer ${token}`);
    return req;
  };

  describe('POST /couriers/auth/pin', () => {
    it('401 on wrong PIN', async () => {
      await http()
        .post('/couriers/auth/pin')
        .send({ phone: fx.courierPhone, pin: '9999' })
        .expect(401);
    });

    it('401 on unknown phone', async () => {
      await http()
        .post('/couriers/auth/pin')
        .send({ phone: '+70000000000', pin: '1234' })
        .expect(401);
    });
  });

  describe('PATCH /couriers/orders/:orderId/status', () => {
    it('401 without token', async () => {
      const id = await createOrderInStatus(OrderStatus.READY);
      await patchStatus(id, 'READY').expect(401);
    });

    it('404 ORDER_NOT_FOUND for a missing order', async () => {
      const res = await patchStatus(
        '99999999-9999-9999-9999-999999999999',
        'READY',
        courierToken,
      ).expect(404);
      expect(res.body.code).toBe('ORDER_NOT_FOUND');
    });

    it('claim: unassigned READY order becomes own and bumps version', async () => {
      const id = await createOrderInStatus(OrderStatus.READY);
      const before = await getOrderState(id);
      expect(before.courierId).toBeNull();

      await patchStatus(id, 'READY', courierToken).expect(200);

      const after = await getOrderState(id);
      expect(after.status).toBe(OrderStatus.READY);
      expect(after.courierId).toBe(fx.courierId);
      expect(after.version).toBe(before.version + 1);
    });

    it('409 COURIER_HAS_ACTIVE_ORDER when claiming a second order', async () => {
      // First claim succeeds.
      const first = await createOrderInStatus(OrderStatus.READY);
      await patchStatus(first, 'READY', courierToken).expect(200);

      // Second claim is rejected — one active delivery per courier.
      const second = await createOrderInStatus(OrderStatus.READY);
      const res = await patchStatus(second, 'READY', courierToken).expect(409);
      expect(res.body.code).toBe('COURIER_HAS_ACTIVE_ORDER');
    });

    it('ON_WAY: own READY order transitions to ON_WAY', async () => {
      const id = await createOrderInStatus(OrderStatus.READY, { courierId: fx.courierId });
      const before = await getOrderState(id);

      await patchStatus(id, 'ON_WAY', courierToken).expect(200);

      const after = await getOrderState(id);
      expect(after.status).toBe(OrderStatus.ON_WAY);
      expect(after.version).toBe(before.version + 1);
    });

    it('403 ORDER_NOT_ASSIGNED_TO_COURIER for ON_WAY on someone else\'s order', async () => {
      const id = await createOrderInStatus(OrderStatus.READY, { courierId: null });
      const res = await patchStatus(id, 'ON_WAY', courierToken).expect(403);
      expect(res.body.code).toBe('ORDER_NOT_ASSIGNED_TO_COURIER');
    });

    it('COMPLETED: own ON_WAY order transitions to COMPLETED with completedAt', async () => {
      const id = await createOrderInStatus(OrderStatus.ON_WAY, { courierId: fx.courierId });

      await patchStatus(id, 'COMPLETED', courierToken).expect(200);

      const after = await getOrderState(id);
      expect(after.status).toBe(OrderStatus.COMPLETED);
      expect(after.completedAt).not.toBeNull();
    });

    it('409 INVALID_ORDER_STATUS_TRANSITION for COMPLETED on a READY order', async () => {
      const id = await createOrderInStatus(OrderStatus.READY, { courierId: fx.courierId });
      const res = await patchStatus(id, 'COMPLETED', courierToken).expect(409);
      expect(res.body.code).toBe('INVALID_ORDER_STATUS_TRANSITION');
    });
  });
});
