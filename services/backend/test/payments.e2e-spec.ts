import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { BadRequestException, INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PaymentStatus, PrismaClient } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';

const TEST_DATABASE_URL = process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';
process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.DISABLE_QUEUES = 'true';
process.env.YOOKASSA_MOCK = 'true';
const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

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

describe('Payments API (e2e)', () => {
  let app: INestApplication;
  let brandId: string;
  let branchId: string;
  let itemId: string;

  beforeAll(async () => {
    execSync('pnpm prisma migrate deploy', {
      cwd: path.resolve(__dirname, '..'),
      env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
      stdio: 'inherit',
    });
    await truncateAll();
    const brand = await prisma.brand.create({ data: { code: 'SHIK_ROLL', name: 'SHIK ROLL' } });
    const branch = await prisma.branch.create({ data: { code: 'A-01', name: 'Branch A1' } });
    await prisma.brandBranch.create({ data: { brandId: brand.id, branchId: branch.id } });
    const menu = await prisma.menu.create({
      data: { brandId: brand.id, name: 'Main Menu', status: 'PUBLISHED', publishedAt: new Date() },
    });
    const category = await prisma.category.create({
      data: { brandId: brand.id, menuId: menu.id, name: 'Роллы', sortOrder: 0, isActive: true },
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
    ({ id: brandId } = brand);
    ({ id: branchId } = branch);
    ({ id: itemId } = item);

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({
      whitelist: true,
      transform: true,
      exceptionFactory: (errors) => new BadRequestException({
        statusCode: 400,
        code: 'VALIDATION_ERROR',
        message: errors.map((error) => Object.values(error.constraints ?? {}).join(', ')).filter(Boolean).join('; '),
      }),
    }));
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
    await prisma.$disconnect();
  });

  const http = () => request(app.getHttpServer());
  async function createOnlineOrder(): Promise<{ id: string; paymentId: string; paymentUrl: string }> {
    const response = await http().post('/orders').send({
      type: 'TAKEAWAY',
      paymentMethod: 'ONLINE',
      brandId,
      branchId,
      items: [{ menuItemId: itemId, quantity: 1 }],
    }).expect(201);
    return response.body;
  }

  it('creates a pending payment together with an ONLINE order', async () => {
    const order = await createOnlineOrder();
    expect(order.paymentId).toMatch(/^mock-/);
    expect(order.paymentUrl).toMatch(/^https:\/\/mock-pay\.shik\.local\//);
    const payment = await prisma.payment.findFirstOrThrow({ where: { orderId: order.id } });
    expect(payment.status).toBe(PaymentStatus.PENDING);
    expect(payment.externalPaymentId).toBe(order.paymentId);
  });

  it('confirms an order after a succeeded webhook', async () => {
    const order = await createOnlineOrder();
    await http().post('/payments/webhook').send({
      type: 'notification',
      event: 'payment.succeeded',
      object: {
        id: order.paymentId,
        status: 'succeeded',
        paid: true,
        amount: { value: '250.00', currency: 'RUB' },
        metadata: { orderId: order.id },
      },
    }).expect(200, { status: 'processed' });

    const updated = await http().get(`/orders/${order.id}`).expect(200);
    expect(updated.body.status).toBe('CONFIRMED');
    expect(updated.body.confirmedAt).toBeTruthy();
    const history = await prisma.orderStatusHistory.findMany({ where: { orderId: order.id } });
    expect(history.map((row) => `${row.previousStatus}->${row.newStatus}`)).toEqual([
      'PENDING_PAYMENT->CONFIRMED',
    ]);
  });

  it('cancels an order through the legacy webhook alias', async () => {
    const order = await createOnlineOrder();
    await http().post('/payments/webhook/yookassa').send({
      type: 'notification',
      event: 'payment.canceled',
      object: {
        id: order.paymentId,
        status: 'canceled',
        paid: false,
        metadata: { orderId: order.id },
      },
    }).expect(200, { status: 'processed' });

    const updated = await http().get(`/orders/${order.id}`).expect(200);
    expect(updated.body.status).toBe('CANCELLED');
    expect(updated.body.cancelledAt).toBeTruthy();
  });

  it('acknowledges malformed and unknown webhooks', async () => {
    await http().post('/payments/webhook')
      .send({ type: 'notification' })
      .expect(200, { status: 'ignored' });
    await http().post('/payments/webhook').send({
      type: 'notification',
      event: 'payment.succeeded',
      object: { id: 'unknown', status: 'succeeded' },
    }).expect(200, { status: 'ignored' });
  });

  it('returns the latest payment for an order', async () => {
    const order = await createOnlineOrder();
    const response = await http().get(`/payments/order/${order.id}`).expect(200);
    expect(response.body.orderId).toBe(order.id);
    expect(response.body.payment.status).toBe('PENDING');
    expect(response.body.payment.amount).toBe(250);
  });
});
