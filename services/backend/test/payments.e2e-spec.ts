import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { BadRequestException, INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PaymentStatus, PrismaClient } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/**
 * E2E coverage of the Payments module:
 *   - POST /payments/create with the dev Mock provider (no API keys):
 *     server-side amount, immediate SUCCEEDED, order NEW -> CONFIRMED with audit;
 *   - idempotency: ORDER_ALREADY_PAID on a second attempt, pending-attempt reuse;
 *   - POST /payments/webhook/yookassa: payment.succeeded settles the payment and
 *     confirms the order (duplicate delivery is a no-op), payment.canceled cancels;
 *   - GET /payments/order/:orderId payment status check.
 *
 * Runs against DATABASE_URL_TEST (migrate deploy + client-side cleanup, same
 * convention as orders.e2e-spec.ts). PAYMENTS_PROVIDER=mock pins the provider
 * selection regardless of the developer's local .env keys.
 */

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';

process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.DISABLE_QUEUES = 'true';
process.env.PAYMENTS_PROVIDER = 'mock';

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

/** Clears every table in FK-safe order using the Prisma client only. */
async function truncateAll(): Promise<void> {
  await prisma.payment.deleteMany();
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
  brandId: string;
  branchId: string;
  itemId: string; // base price 250
}

async function seedFixtures(): Promise<Fixture> {
  const brand = await prisma.brand.create({
    data: { code: 'SHIK_ROLL', name: 'SHIK ROLL' },
  });
  const branch = await prisma.branch.create({
    data: { code: 'A-01', name: 'Branch A1' },
  });
  await prisma.brandBranch.create({
    data: { brandId: brand.id, branchId: branch.id },
  });
  const menu = await prisma.menu.create({
    data: {
      brandId: brand.id,
      name: 'Main Menu',
      status: 'PUBLISHED',
      publishedAt: new Date(),
    },
  });
  const category = await prisma.category.create({
    data: {
      brandId: brand.id,
      menuId: menu.id,
      name: 'Роллы',
      sortOrder: 0,
      isActive: true,
    },
  });
  const item = await prisma.menuItem.create({
    data: {
      brandId: brand.id,
      menuId: menu.id,
      categoryId: category.id,
      sku: 'ROLL-001',
      name: 'Калифорния',
      slug: 'kaliforniya',
      basePrice: 250,
      status: 'PUBLISHED',
    },
  });
  return { brandId: brand.id, branchId: branch.id, itemId: item.id };
}

describe('Payments API (e2e)', () => {
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

  async function createOrder(): Promise<string> {
    const res = await http()
      .post('/orders')
      .send({
        type: 'TAKEAWAY',
        brandId: fx.brandId,
        branchId: fx.branchId,
        items: [{ menuItemId: fx.itemId, quantity: 1 }],
      })
      .expect(201);
    return res.body.id as string;
  }

  describe('POST /payments/create', () => {
    it('creates a mock payment that settles immediately and confirms the order', async () => {
      const orderId = await createOrder();

      const res = await http()
        .post('/payments/create')
        .send({ orderId })
        .expect(201);

      expect(res.body.orderId).toBe(orderId);
      expect(res.body.provider).toBe('YOOKASSA');
      expect(res.body.status).toBe('SUCCEEDED');
      expect(res.body.amount).toBe(250); // server-side order total
      expect(res.body.currency).toBe('RUB');
      expect(res.body.paymentUrl).toMatch(/^https:\/\/mock-pay\.shik\.local\//);
      expect(res.body.externalPaymentId).toMatch(/^mock-/);
      expect(res.body.idempotenceKey).toBe(`pay_${orderId}_1`);

      // The order moved NEW -> CONFIRMED with an audit entry (DB-608).
      const order = await http().get(`/orders/${orderId}`).expect(200);
      expect(order.body.status).toBe('CONFIRMED');
      const history = await prisma.orderStatusHistory.findMany({
        where: { orderId },
      });
      expect(history).toHaveLength(1);
      expect(history[0]).toMatchObject({
        previousStatus: 'NEW',
        newStatus: 'CONFIRMED',
        reason: 'Online payment succeeded',
      });
    });

    it('409 ORDER_ALREADY_PAID on a second payment attempt', async () => {
      const orderId = await createOrder();
      await http().post('/payments/create').send({ orderId }).expect(201);

      const res = await http()
        .post('/payments/create')
        .send({ orderId })
        .expect(409);
      expect(res.body.code).toBe('ORDER_ALREADY_PAID');

      const payments = await prisma.payment.findMany({ where: { orderId } });
      expect(payments).toHaveLength(1);
    });

    it('reuses the existing pending attempt instead of creating a new one', async () => {
      const orderId = await createOrder();
      const pending = await prisma.payment.create({
        data: {
          orderId,
          provider: 'YOOKASSA',
          status: 'PENDING',
          amount: 250,
          paymentUrl: 'https://yoomoney.ru/checkout/existing',
          externalPaymentId: 'ext-pending-1',
          idempotenceKey: `pay_${orderId}_1`,
        },
      });

      const res = await http()
        .post('/payments/create')
        .send({ orderId })
        .expect(201);

      expect(res.body.id).toBe(pending.id);
      expect(res.body.status).toBe('PENDING');
      expect(res.body.paymentUrl).toBe('https://yoomoney.ru/checkout/existing');
      const payments = await prisma.payment.findMany({ where: { orderId } });
      expect(payments).toHaveLength(1);
    });

    it('404 ORDER_NOT_FOUND for a missing order', async () => {
      const res = await http()
        .post('/payments/create')
        .send({ orderId: '99999999-9999-4999-9999-999999999999' })
        .expect(404);
      expect(res.body.code).toBe('ORDER_NOT_FOUND');
    });

    it('400 VALIDATION_ERROR for a malformed orderId', async () => {
      const res = await http()
        .post('/payments/create')
        .send({ orderId: 'not-a-uuid' })
        .expect(400);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('POST /payments/webhook/yookassa', () => {
    async function createPendingPayment(orderId: string, externalId: string) {
      return prisma.payment.create({
        data: {
          orderId,
          provider: 'YOOKASSA',
          status: 'PENDING',
          amount: 250,
          paymentUrl: 'https://yoomoney.ru/checkout/pending',
          externalPaymentId: externalId,
          idempotenceKey: `pay_${orderId}_1`,
        },
      });
    }

    it('payment.succeeded settles the payment and confirms the order', async () => {
      const orderId = await createOrder();
      const payment = await createPendingPayment(orderId, 'yk-ext-e2e-1');

      const res = await http()
        .post('/payments/webhook/yookassa')
        .send({
          type: 'notification',
          event: 'payment.succeeded',
          object: {
            id: 'yk-ext-e2e-1',
            status: 'succeeded',
            paid: true,
            amount: { value: '250.00', currency: 'RUB' },
          },
        })
        .expect(200);
      expect(res.body).toEqual({ status: 'processed' });

      const updated = await prisma.payment.findUnique({ where: { id: payment.id } });
      expect(updated?.status).toBe(PaymentStatus.SUCCEEDED);

      const order = await http().get(`/orders/${orderId}`).expect(200);
      expect(order.body.status).toBe('CONFIRMED');
      const history = await prisma.orderStatusHistory.findMany({
        where: { orderId },
      });
      expect(history.map((h) => `${h.previousStatus}->${h.newStatus}`)).toEqual([
        'NEW->CONFIRMED',
      ]);
    });

    it('duplicate payment.succeeded delivery is a no-op', async () => {
      const orderId = await createOrder();
      await createPendingPayment(orderId, 'yk-ext-e2e-2');
      const payload = {
        type: 'notification',
        event: 'payment.succeeded',
        object: { id: 'yk-ext-e2e-2', status: 'succeeded', paid: true },
      };

      await http().post('/payments/webhook/yookassa').send(payload).expect(200);
      const res = await http()
        .post('/payments/webhook/yookassa')
        .send(payload)
        .expect(200);
      expect(res.body).toEqual({ status: 'processed' });

      // Exactly one payment and one audit entry — no double settlement.
      const payments = await prisma.payment.findMany({ where: { orderId } });
      expect(payments).toHaveLength(1);
      expect(payments[0].status).toBe(PaymentStatus.SUCCEEDED);
      const history = await prisma.orderStatusHistory.findMany({
        where: { orderId },
      });
      expect(history).toHaveLength(1);
    });

    it('payment.canceled cancels the pending payment and leaves the order NEW', async () => {
      const orderId = await createOrder();
      const payment = await createPendingPayment(orderId, 'yk-ext-e2e-3');

      const res = await http()
        .post('/payments/webhook/yookassa')
        .send({
          type: 'notification',
          event: 'payment.canceled',
          object: { id: 'yk-ext-e2e-3', status: 'canceled', paid: false },
        })
        .expect(200);
      expect(res.body).toEqual({ status: 'processed' });

      const updated = await prisma.payment.findUnique({ where: { id: payment.id } });
      expect(updated?.status).toBe(PaymentStatus.CANCELED);
      const order = await http().get(`/orders/${orderId}`).expect(200);
      expect(order.body.status).toBe('NEW');

      // A fresh attempt is allowed after a cancellation.
      const retry = await http()
        .post('/payments/create')
        .send({ orderId })
        .expect(201);
      expect(retry.body.status).toBe('SUCCEEDED');
      expect(retry.body.idempotenceKey).toBe(`pay_${orderId}_2`);
    });

    it('acknowledges webhooks for unknown payments', async () => {
      const res = await http()
        .post('/payments/webhook/yookassa')
        .send({
          type: 'notification',
          event: 'payment.succeeded',
          object: { id: 'yk-unknown', status: 'succeeded', paid: true },
        })
        .expect(200);
      expect(res.body).toEqual({ status: 'ignored' });
    });
  });

  describe('GET /payments/order/:orderId', () => {
    it('returns the latest payment for the order', async () => {
      const orderId = await createOrder();
      await http().post('/payments/create').send({ orderId }).expect(201);

      const res = await http().get(`/payments/order/${orderId}`).expect(200);
      expect(res.body.orderId).toBe(orderId);
      expect(res.body.payment.status).toBe('SUCCEEDED');
      expect(res.body.payment.amount).toBe(250);
    });

    it('returns payment: null for an order without attempts', async () => {
      const orderId = await createOrder();

      const res = await http().get(`/payments/order/${orderId}`).expect(200);
      expect(res.body).toEqual({ orderId, payment: null });
    });

    it('404 ORDER_NOT_FOUND for a missing order', async () => {
      const res = await http()
        .get('/payments/order/99999999-9999-9999-9999-999999999999')
        .expect(404);
      expect(res.body.code).toBe('ORDER_NOT_FOUND');
    });
  });
});
