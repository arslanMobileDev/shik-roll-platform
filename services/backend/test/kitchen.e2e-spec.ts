import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { INestApplication, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
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
  await prisma.cookShift.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.orderStatusHistory.deleteMany();
  await prisma.orderItemModifier.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.kitchenTerminal.deleteMany();
  await prisma.menuItemModifierGroup.deleteMany();
  await prisma.modifierItem.deleteMany();
  await prisma.modifierGroup.deleteMany();
  await prisma.stopListEntry.deleteMany();
  await prisma.branchMenuItemAvailability.deleteMany();
  await prisma.menuItemPrice.deleteMany();
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
  menuItemId: string;
  terminalCode: string;
  terminalPin: string;
}

async function seedFixtures(): Promise<Fixture> {
  const brand = await prisma.brand.create({
    data: { code: 'KITCHEN_E2E', name: 'Kitchen E2E' },
  });
  const branch = await prisma.branch.create({
    data: { code: 'K-E2E-01', name: 'Kitchen E2E Branch' },
  });
  await prisma.brandBranch.create({
    data: { brandId: brand.id, branchId: branch.id },
  });

  const menu = await prisma.menu.create({
    data: { brandId: brand.id, name: 'K Menu', status: 'PUBLISHED', publishedAt: new Date() },
  });
  const category = await prisma.category.create({
    data: { brandId: brand.id, menuId: menu.id, name: 'Роллы', sortOrder: 0, isActive: true },
  });
  const menuItem = await prisma.menuItem.create({
    data: {
      brandId: brand.id,
      menuId: menu.id,
      categoryId: category.id,
      sku: 'K-001',
      name: 'Ролл',
      slug: 'roll',
      basePrice: 100,
      status: 'PUBLISHED',
    },
  });

  const terminalCode = 'K-E2E-T1';
  const terminalPin = '1234';
  await prisma.kitchenTerminal.create({
    data: {
      code: terminalCode,
      name: 'Kitchen E2E Terminal',
      pinHash: await bcrypt.hash(terminalPin, 4),
      branchId: branch.id,
      isActive: true,
    },
  });

  return {
    brandId: brand.id,
    branchId: branch.id,
    menuItemId: menuItem.id,
    terminalCode,
    terminalPin,
  };
}

describe('Kitchen API (e2e)', () => {
  let app: INestApplication;
  let fx: Fixture;
  let kitchenToken: string;

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
      .post('/kitchen/auth/pin')
      .send({ terminalCode: fx.terminalCode, pin: fx.terminalPin })
      .expect(201);
    kitchenToken = login.body.token;
  });

  afterAll(async () => {
    await app?.close();
    await prisma.$disconnect();
  });

  const http = () => request(app.getHttpServer());

  const createOrder = async (): Promise<string> => {
    const res = await http()
      .post('/orders')
      .send({
        type: 'TAKEAWAY',
        brandId: fx.brandId,
        branchId: fx.branchId,
        items: [{ menuItemId: fx.menuItemId, quantity: 1 }],
      })
      .expect(201);
    return res.body.id;
  };

  const getOrderState = async (id: string): Promise<{ status: string; version: number }> => {
    const o = await prisma.order.findUniqueOrThrow({ where: { id } });
    return { status: o.status, version: o.version };
  };

  const patchStatus = (id: string, body: object, token?: string) => {
    const req = http().patch(`/kitchen/orders/${id}/status`).send(body);
    if (token) req.set('Authorization', `Bearer ${token}`);
    return req;
  };

  describe('POST /kitchen/auth/pin', () => {
    it('401 on wrong PIN', async () => {
      await http()
        .post('/kitchen/auth/pin')
        .send({ terminalCode: fx.terminalCode, pin: '9999' })
        .expect(401);
    });

    it('401 on unknown terminal code', async () => {
      await http()
        .post('/kitchen/auth/pin')
        .send({ terminalCode: 'UNKNOWN-CODE', pin: '1234' })
        .expect(401);
    });
  });

  describe('PATCH /kitchen/orders/:orderId/status', () => {
    it('401 without token', async () => {
      const id = await createOrder();
      await patchStatus(id, { status: 'COOKING', expectedVersion: 1 }).expect(401);
    });

    it('NEW -> COOKING sets status and bumps version', async () => {
      const id = await createOrder();
      const { version } = await getOrderState(id);
      await patchStatus(id, { status: 'COOKING', expectedVersion: version }, kitchenToken).expect(200);
      const after = await getOrderState(id);
      expect(after.status).toBe('COOKING');
      expect(after.version).toBe(version + 1);
    });

    it('COOKING -> READY', async () => {
      const id = await createOrder();
      const v1 = (await getOrderState(id)).version;
      await patchStatus(id, { status: 'COOKING', expectedVersion: v1 }, kitchenToken).expect(200);
      const v2 = (await getOrderState(id)).version;
      await patchStatus(id, { status: 'READY', expectedVersion: v2 }, kitchenToken).expect(200);
      expect((await getOrderState(id)).status).toBe('READY');
    });

    it('409 ORDER_VERSION_CONFLICT on stale expectedVersion', async () => {
      const id = await createOrder();
      const res = await patchStatus(
        id,
        { status: 'COOKING', expectedVersion: 999 },
        kitchenToken,
      ).expect(409);
      expect(res.body.code).toBe('ORDER_VERSION_CONFLICT');
    });

    it('409 INVALID_ORDER_STATUS_TRANSITION for READY -> COOKING', async () => {
      const id = await createOrder();
      const v1 = (await getOrderState(id)).version;
      await patchStatus(id, { status: 'COOKING', expectedVersion: v1 }, kitchenToken).expect(200);
      const v2 = (await getOrderState(id)).version;
      await patchStatus(id, { status: 'READY', expectedVersion: v2 }, kitchenToken).expect(200);
      const v3 = (await getOrderState(id)).version;
      const res = await patchStatus(
        id,
        { status: 'COOKING', expectedVersion: v3 },
        kitchenToken,
      ).expect(409);
      expect(res.body.code).toBe('INVALID_ORDER_STATUS_TRANSITION');
    });

    it('404 ORDER_NOT_FOUND for a missing order', async () => {
      const res = await patchStatus(
        '99999999-9999-9999-9999-999999999999',
        { status: 'COOKING', expectedVersion: 1 },
        kitchenToken,
      ).expect(404);
      expect(res.body.code).toBe('ORDER_NOT_FOUND');
    });
  });
});
