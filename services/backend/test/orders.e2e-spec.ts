import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { INestApplication, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { OrderStatus, PrismaClient } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/**
 * E2E coverage of the Order module (API-707 surface, DB-608, BE-907):
 *   - POST /orders with server-side pricing (base + branch override + modifiers);
 *   - GET /orders filters (brandId, branchId, status) and pagination;
 *   - GET /orders/:id;
 *   - PATCH /orders/:id/status full lifecycle and INVALID_ORDER_STATUS_TRANSITION;
 *   - order_status_history audit of every transition.
 *
 * Runs against DATABASE_URL_TEST (migrate deploy + client-side cleanup, same
 * convention as menu.e2e-spec.ts). BullMQ/Redis is replaced by an in-memory
 * stub: the BullModule.forRoot connection factory tolerates an absent Redis
 * until a queue is actually used, and all queue use goes through the stub.
 */

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';

process.env.DATABASE_URL = TEST_DATABASE_URL;
// No Redis in the test environment: QueuesModule swaps BullMQ for in-memory stubs.
process.env.DISABLE_QUEUES = 'true';

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

/** Clears every table in FK-safe order using the Prisma client only. */
async function truncateAll(): Promise<void> {
  await prisma.orderStatusHistory.deleteMany();
  await prisma.orderItemModifier.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.menuItemModifierGroup.deleteMany();
  await prisma.modifierItem.deleteMany();
  await prisma.modifierGroup.deleteMany();
  await prisma.stopListEntry.deleteMany();
  await prisma.branchMenuItemAvailability.deleteMany();
  await prisma.menuItemPrice.deleteMany();
  await prisma.menuItemCertification.deleteMany();
  await prisma.certificationTag.deleteMany();
  await prisma.menuItemIngredient.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.menuItem.deleteMany();
  await prisma.category.deleteMany();
  await prisma.menu.deleteMany();
  await prisma.brandBranch.deleteMany();
  await prisma.branch.deleteMany();
  await prisma.brand.deleteMany();
}

interface Fixture {
  brandA: string;
  brandB: string;
  branchA1: string;
  branchA2: string;
  branchB1: string;
  itemPhiladelphia: string; // base 400 @ brand A, override 450 @ branchA1
  itemCalifornia: string; // base 250 @ brand A, no override
  itemBrandB: string;
  itemDraft: string; // DRAFT — must be rejected on order creation
  modifierTobiko: string; // +50
}

async function seedFixtures(): Promise<Fixture> {
  const brandA = await prisma.brand.create({ data: { code: 'SHIK_ROLL', name: 'SHIK ROLL' } });
  const brandB = await prisma.brand.create({ data: { code: 'OTHER_BRAND', name: 'Other Brand' } });

  const branchA1 = await prisma.branch.create({ data: { code: 'A-01', name: 'Branch A1' } });
  const branchA2 = await prisma.branch.create({ data: { code: 'A-02', name: 'Branch A2' } });
  const branchB1 = await prisma.branch.create({ data: { code: 'B-01', name: 'Branch B1' } });

  await prisma.brandBranch.createMany({
    data: [
      { brandId: brandA.id, branchId: branchA1.id },
      { brandId: brandA.id, branchId: branchA2.id },
      { brandId: brandB.id, branchId: branchB1.id },
    ],
  });

  const menuA = await prisma.menu.create({
    data: { brandId: brandA.id, name: 'Main Menu', status: 'PUBLISHED', publishedAt: new Date() },
  });
  const menuB = await prisma.menu.create({
    data: { brandId: brandB.id, name: 'Other Menu', status: 'PUBLISHED', publishedAt: new Date() },
  });

  const categoryRolls = await prisma.category.create({
    data: { brandId: brandA.id, menuId: menuA.id, name: 'Роллы', sortOrder: 0, isActive: true },
  });
  const categoryB = await prisma.category.create({
    data: { brandId: brandB.id, menuId: menuB.id, name: 'Burgers', sortOrder: 0, isActive: true },
  });

  const sizeGroup = await prisma.modifierGroup.create({
    data: {
      brandId: brandA.id,
      name: 'Добавки',
      selectionType: 'MULTIPLE',
      minSelected: 0,
      maxSelected: 5,
      isRequired: false,
    },
  });
  const modifierTobiko = await prisma.modifierItem.create({
    data: { groupId: sizeGroup.id, name: 'Икра тобико', price: 50, isActive: true },
  });

  const itemPhiladelphia = await prisma.menuItem.create({
    data: {
      brandId: brandA.id,
      menuId: menuA.id,
      categoryId: categoryRolls.id,
      sku: 'ROLL-001',
      name: 'Филадельфия',
      slug: 'filadelfiya',
      basePrice: 400,
      status: 'PUBLISHED',
    },
  });
  const itemCalifornia = await prisma.menuItem.create({
    data: {
      brandId: brandA.id,
      menuId: menuA.id,
      categoryId: categoryRolls.id,
      sku: 'ROLL-002',
      name: 'Калифорния',
      slug: 'kaliforniya',
      basePrice: 250,
      status: 'PUBLISHED',
    },
  });
  const itemDraft = await prisma.menuItem.create({
    data: {
      brandId: brandA.id,
      menuId: menuA.id,
      categoryId: categoryRolls.id,
      sku: 'ROLL-003',
      name: 'Черновик',
      slug: 'chernovik',
      basePrice: 100,
      status: 'DRAFT',
    },
  });
  const itemBrandB = await prisma.menuItem.create({
    data: {
      brandId: brandB.id,
      menuId: menuB.id,
      categoryId: categoryB.id,
      sku: 'BURG-001',
      name: 'Бургер',
      slug: 'burger',
      basePrice: 300,
      status: 'PUBLISHED',
    },
  });

  await prisma.menuItemPrice.create({
    data: { menuItemId: itemPhiladelphia.id, branchId: branchA1.id, price: 450 },
  });

  return {
    brandA: brandA.id,
    brandB: brandB.id,
    branchA1: branchA1.id,
    branchA2: branchA2.id,
    branchB1: branchB1.id,
    itemPhiladelphia: itemPhiladelphia.id,
    itemCalifornia: itemCalifornia.id,
    itemBrandB: itemBrandB.id,
    itemDraft: itemDraft.id,
    modifierTobiko: modifierTobiko.id,
  };
}

describe('Orders API (e2e)', () => {
  let app: INestApplication;
  let fx: Fixture;

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
              .map((error) => Object.values(error.constraints ?? {}).join(', '))
              .filter(Boolean)
              .join('; '),
          }),
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
    await prisma.$disconnect();
  });

  const http = () => request(app.getHttpServer());

  describe('POST /orders', () => {
    it('creates an order with server-side pricing (branch override + modifiers)', async () => {
      const res = await http()
        .post('/orders')
        .send({
          type: 'DINE_IN',
          brandId: fx.brandA,
          branchId: fx.branchA1,
          tableNumber: '7',
          items: [
            {
              menuItemId: fx.itemPhiladelphia,
              quantity: 2,
              modifiers: [{ modifierItemId: fx.modifierTobiko, quantity: 1 }],
            },
            { menuItemId: fx.itemCalifornia, quantity: 1 },
          ],
        })
        .expect(201);

      expect(res.body.status).toBe('NEW');
      expect(res.body.orderNumber).toMatch(/^[0-9A-F]{4}-\d{8}-0001$/);
      // Philadelphia: (450 override + 50 tobiko) * 2 = 1000; California: 250.
      expect(res.body.subtotalAmount).toBe(1250);
      expect(res.body.totalAmount).toBe(1250);
      expect(res.body.currency).toBe('RUB');
      expect(res.body.items).toHaveLength(2);
      const philadelphia = res.body.items.find(
        (i: { menuItemId: string }) => i.menuItemId === fx.itemPhiladelphia,
      );
      expect(philadelphia).toMatchObject({
        name: 'Филадельфия',
        quantity: 2,
        unitPrice: 450,
        totalAmount: 1000,
      });
      expect(philadelphia.modifiers).toEqual([
        expect.objectContaining({ name: 'Икра тобико', priceDelta: 50, quantity: 1 }),
      ]);
    });

    it('uses the base price at branches without an override', async () => {
      const res = await http()
        .post('/orders')
        .send({
          type: 'TAKEAWAY',
          brandId: fx.brandA,
          branchId: fx.branchA2,
          items: [{ menuItemId: fx.itemPhiladelphia, quantity: 1 }],
        })
        .expect(201);
      expect(res.body.totalAmount).toBe(400);
    });

    it('rejects a DRAFT product with PRODUCT_UNAVAILABLE', async () => {
      const res = await http()
        .post('/orders')
        .send({
          type: 'DINE_IN',
          brandId: fx.brandA,
          branchId: fx.branchA1,
          items: [{ menuItemId: fx.itemDraft, quantity: 1 }],
        })
        .expect(400);
      expect(res.body.code).toBe('PRODUCT_UNAVAILABLE');
    });

    it('rejects a product of another brand (multi-brand isolation)', async () => {
      const res = await http()
        .post('/orders')
        .send({
          type: 'DELIVERY',
          brandId: fx.brandA,
          branchId: fx.branchA1,
          deliveryAddress: 'ул. Пушкина, 1',
          items: [{ menuItemId: fx.itemBrandB, quantity: 1 }],
        })
        .expect(400);
      expect(res.body.code).toBe('PRODUCT_UNAVAILABLE');
    });

    it('rejects an empty order with VALIDATION_ERROR', async () => {
      const res = await http()
        .post('/orders')
        .send({ type: 'DINE_IN', brandId: fx.brandA, branchId: fx.branchA1, items: [] })
        .expect(400);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('GET /orders', () => {
    it('filters by branchId and status with pagination meta', async () => {
      const res = await http()
        .get(`/orders?branchId=${fx.branchA1}&status=NEW`)
        .expect(200);
      expect(res.body.meta.total).toBeGreaterThanOrEqual(1);
      expect(res.body.meta.page).toBe(1);
      expect(
        res.body.data.every(
          (o: { branchId: string; status: string }) =>
            o.branchId === fx.branchA1 && o.status === 'NEW',
        ),
      ).toBe(true);
    });

    it('multi-brand isolation: brand B sees no brand A orders', async () => {
      const res = await http().get(`/orders?brandId=${fx.brandB}`).expect(200);
      expect(res.body.meta.total).toBe(0);
    });

    it('paginates', async () => {
      const res = await http().get('/orders?page=1&limit=1').expect(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.meta.total).toBeGreaterThanOrEqual(2);
      expect(res.body.meta.totalPages).toBeGreaterThanOrEqual(2);
    });
  });

  describe('GET /orders/:id', () => {
    it('returns the order', async () => {
      const created = await http()
        .post('/orders')
        .send({
          type: 'TAKEAWAY',
          brandId: fx.brandA,
          branchId: fx.branchA1,
          items: [{ menuItemId: fx.itemCalifornia, quantity: 1 }],
        })
        .expect(201);
      const res = await http().get(`/orders/${created.body.id}`).expect(200);
      expect(res.body.id).toBe(created.body.id);
      expect(res.body.items[0].name).toBe('Калифорния');
    });

    it('404 ORDER_NOT_FOUND for a missing id', async () => {
      const res = await http()
        .get('/orders/99999999-9999-9999-9999-999999999999')
        .expect(404);
      expect(res.body.code).toBe('ORDER_NOT_FOUND');
    });
  });

  describe('PATCH /orders/:id/status', () => {
    it('walks the full lifecycle NEW -> CONFIRMED -> COOKING -> READY -> COMPLETED', async () => {
      const created = await http()
        .post('/orders')
        .send({
          type: 'DINE_IN',
          brandId: fx.brandA,
          branchId: fx.branchA1,
          items: [{ menuItemId: fx.itemCalifornia, quantity: 1 }],
        })
        .expect(201);
      const id = created.body.id as string;

      for (const status of ['CONFIRMED', 'COOKING', 'READY', 'COMPLETED'] as const) {
        const res = await http().patch(`/orders/${id}/status`).send({ status }).expect(200);
        expect(res.body.status).toBe(status);
      }
      const completed = await http().get(`/orders/${id}`).expect(200);
      expect(completed.body.completedAt).not.toBeNull();

      // Every transition is audited (DB-608 order_status_history).
      const history = await prisma.orderStatusHistory.findMany({
        where: { orderId: id },
        orderBy: { changedAt: 'asc' },
      });
      expect(history.map((h) => `${h.previousStatus}->${h.newStatus}`)).toEqual([
        'NEW->CONFIRMED',
        'CONFIRMED->COOKING',
        'COOKING->READY',
        'READY->COMPLETED',
      ]);
    });

    it('cancels from NEW with a reason', async () => {
      const created = await http()
        .post('/orders')
        .send({
          type: 'DELIVERY',
          brandId: fx.brandA,
          branchId: fx.branchA1,
          deliveryAddress: 'ул. Лермонтова, 5',
          items: [{ menuItemId: fx.itemCalifornia, quantity: 1 }],
        })
        .expect(201);

      const res = await http()
        .patch(`/orders/${created.body.id}/status`)
        .send({ status: 'CANCELLED', reason: 'Клиент передумал' })
        .expect(200);
      expect(res.body.status).toBe('CANCELLED');
      expect(res.body.cancelledAt).not.toBeNull();

      const order = await prisma.order.findUnique({ where: { id: created.body.id } });
      expect(order?.cancelReason).toBe('Клиент передумал');
    });

    it.each([
      ['NEW', 'COOKING'],
      ['NEW', 'READY'],
      ['NEW', 'COMPLETED'],
      ['CONFIRMED', 'READY'],
      ['COOKING', 'COMPLETED'],
      ['READY', 'CONFIRMED'],
    ])(
      'rejects %s -> %s with 400 INVALID_ORDER_STATUS_TRANSITION',
      async (from, to) => {
        const created = await http()
          .post('/orders')
          .send({
            type: 'TAKEAWAY',
            brandId: fx.brandA,
            branchId: fx.branchA1,
            items: [{ menuItemId: fx.itemCalifornia, quantity: 1 }],
          })
          .expect(201);
        const id = created.body.id as string;

        // Walk to the `from` state through legal transitions.
        const path: Record<string, string[]> = {
          NEW: [],
          CONFIRMED: ['CONFIRMED'],
          COOKING: ['CONFIRMED', 'COOKING'],
          READY: ['CONFIRMED', 'COOKING', 'READY'],
        };
        for (const step of path[from]) {
          await http().patch(`/orders/${id}/status`).send({ status: step }).expect(200);
        }

        const res = await http()
          .patch(`/orders/${id}/status`)
          .send({ status: to })
          .expect(400);
        expect(res.body.code).toBe('INVALID_ORDER_STATUS_TRANSITION');
        expect(res.body.message).toBe(`Invalid order status transition: ${from} -> ${to}`);

        // The order did not move.
        const after = await http().get(`/orders/${id}`).expect(200);
        expect(after.body.status).toBe(from);
      },
    );

    it('rejects any transition out of terminal COMPLETED', async () => {
      const created = await http()
        .post('/orders')
        .send({
          type: 'DINE_IN',
          brandId: fx.brandA,
          branchId: fx.branchA1,
          items: [{ menuItemId: fx.itemCalifornia, quantity: 1 }],
        })
        .expect(201);
      const id = created.body.id as string;
      for (const status of ['CONFIRMED', 'COOKING', 'READY', 'COMPLETED']) {
        await http().patch(`/orders/${id}/status`).send({ status }).expect(200);
      }
      const res = await http()
        .patch(`/orders/${id}/status`)
        .send({ status: OrderStatus.CANCELLED })
        .expect(400);
      expect(res.body.code).toBe('INVALID_ORDER_STATUS_TRANSITION');
    });

    it('404 ORDER_NOT_FOUND for a missing id', async () => {
      const res = await http()
        .patch('/orders/99999999-9999-9999-9999-999999999999/status')
        .send({ status: 'CONFIRMED' })
        .expect(404);
      expect(res.body.code).toBe('ORDER_NOT_FOUND');
    });
  });
});
