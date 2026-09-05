import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { INestApplication, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import {
  DEV_OTP_CODE,
  OTP_MAX_ATTEMPTS,
  OTP_TTL_SECONDS,
} from '../src/modules/auth/auth.config';

/**
 * E2E coverage of the guest auth bounded context (phone + OTP -> JWT):
 *   - POST /auth/otp/send — phone validation, OTP issue (fixed dev code 1111),
 *     resend rate limit (1 code per minute per phone);
 *   - POST /auth/otp/verify — code check, max-attempts lockout, customer
 *     auto-provisioning, token pair;
 *   - GET /auth/me — JwtAuthGuard protection of the profile endpoint;
 *   - GET /orders/my — the guest's own order history (auth required,
 *     pagination, newest first);
 *   - guest scoping of GET /orders by customerId from the JWT.
 *
 * Runs against DATABASE_URL_TEST (same convention as orders.e2e-spec.ts).
 * No Redis and no SMS_PROVIDER in the test environment (NODE_ENV=test):
 * the OTP store is in-memory and the code is the fixed dev code '1111'.
 *
 * Rate limiting note: a phone can receive only one code per minute, so every
 * flow below uses its own unique phone number (nextPhone()).
 */

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';

process.env.DATABASE_URL = TEST_DATABASE_URL;
delete process.env.SMS_PROVIDER;
delete process.env.DEV_OTP;
delete process.env.REDIS_URL;
delete process.env.REDIS_HOST;

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

/** Clears every table touched by this spec in FK-safe order. */
async function truncateAll(): Promise<void> {
  await prisma.payment.deleteMany();
  await prisma.orderStatusHistory.deleteMany();
  await prisma.orderItemModifier.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.customer.deleteMany();
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

/** Unique +7 phone per call — the resend cooldown is per phone. */
let phoneSeq = 0;
function nextPhone(): string {
  phoneSeq += 1;
  return `+7999${String(phoneSeq).padStart(7, '0')}`;
}

/** Registers / re-authenticates a guest and returns the access token + customer id. */
async function signInGuest(phone: string): Promise<{ token: string; customerId: string }> {
  const res = await globalApp
    .post('/auth/otp/send')
    .send({ phone })
    .expect(200);
  expect(res.body.expiresInSeconds).toBe(OTP_TTL_SECONDS);
  expect(res.body.devCode).toBe(DEV_OTP_CODE);
  const verified = await globalApp
    .post('/auth/otp/verify')
    .send({ phone, code: DEV_OTP_CODE })
    .expect(200);
  return {
    token: verified.body.accessToken as string,
    customerId: verified.body.customer.id as string,
  };
}

let globalApp: ReturnType<typeof request>;

describe('Auth API (e2e)', () => {
  let app: INestApplication;
  let brandId: string;
  let branchId: string;
  let menuItemId: string;

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
        name: 'Филадельфия',
        slug: 'filadelfiya',
        basePrice: 400,
        status: 'PUBLISHED',
      },
    });
    brandId = brand.id;
    branchId = branch.id;
    menuItemId = item.id;

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
    globalApp = request(app.getHttpServer());
  });

  afterAll(async () => {
    await app?.close();
    await prisma.$disconnect();
  });

  const http = () => request(app.getHttpServer());

  describe('POST /auth/otp/send', () => {
    it('issues an OTP for a valid +7 phone and returns the fixed dev code', async () => {
      const phone = nextPhone();
      const res = await http().post('/auth/otp/send').send({ phone }).expect(200);
      expect(res.body).toEqual({
        phone,
        expiresInSeconds: OTP_TTL_SECONDS,
        devCode: DEV_OTP_CODE,
      });
      expect(OTP_TTL_SECONDS).toBe(300);
    });

    it('rate limits resend: a second code within a minute is rejected (429 OTP_SEND_RATE_LIMITED)', async () => {
      const phone = nextPhone();
      await http().post('/auth/otp/send').send({ phone }).expect(200);
      const res = await http().post('/auth/otp/send').send({ phone }).expect(429);
      expect(res.body.code).toBe('OTP_SEND_RATE_LIMITED');
    });

    it.each([['89991111111'], ['+7999111111'], ['+799911111111'], ['+19991111111'], ['abc']])(
      'rejects invalid phone %s with VALIDATION_ERROR',
      async (phone) => {
        const res = await http().post('/auth/otp/send').send({ phone }).expect(400);
        expect(res.body.code).toBe('VALIDATION_ERROR');
      },
    );
  });

  describe('POST /auth/otp/verify', () => {
    it('rejects a phone that never requested a code (401 OTP_EXPIRED)', async () => {
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: nextPhone(), code: DEV_OTP_CODE })
        .expect(401);
      expect(res.body.code).toBe('OTP_EXPIRED');
    });

    it('rejects a wrong code (401 OTP_INVALID)', async () => {
      const phone = nextPhone();
      await http().post('/auth/otp/send').send({ phone }).expect(200);
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone, code: '0000' })
        .expect(401);
      expect(res.body.code).toBe('OTP_INVALID');
    });

    it('locks the code out after 5 wrong attempts (429 OTP_ATTEMPTS_EXCEEDED)', async () => {
      const phone = nextPhone();
      await http().post('/auth/otp/send').send({ phone }).expect(200);
      for (let attempt = 1; attempt < OTP_MAX_ATTEMPTS; attempt += 1) {
        await http()
          .post('/auth/otp/verify')
          .send({ phone, code: '0000' })
          .expect(401);
      }
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone, code: '0000' })
        .expect(429);
      expect(res.body.code).toBe('OTP_ATTEMPTS_EXCEEDED');

      // The burned code no longer verifies even with the right value.
      const burned = await http()
        .post('/auth/otp/verify')
        .send({ phone, code: DEV_OTP_CODE })
        .expect(401);
      expect(burned.body.code).toBe('OTP_EXPIRED');
    });

    it('rejects a malformed code with VALIDATION_ERROR', async () => {
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: nextPhone(), code: '12ab' })
        .expect(400);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });

    it('verifies the code, auto-creates the customer and returns a token pair', async () => {
      const phone = nextPhone();
      await http().post('/auth/otp/send').send({ phone }).expect(200);
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone, code: DEV_OTP_CODE })
        .expect(200);

      expect(res.body.tokenType).toBe('Bearer');
      expect(res.body.accessToken).toEqual(expect.any(String));
      expect(res.body.refreshToken).toEqual(expect.any(String));
      expect(res.body.expiresInSeconds).toBe(30 * 24 * 60 * 60);
      expect(res.body.customer).toMatchObject({
        phone,
        name: null,
        email: null,
        role: 'CUSTOMER',
      });

      const stored = await prisma.customer.findUnique({ where: { phone } });
      expect(stored?.id).toBe(res.body.customer.id);
      expect(stored?.role).toBe('CUSTOMER');
    });

    it('rejects replay of an already verified code (401 OTP_EXPIRED)', async () => {
      const phone = nextPhone();
      await http().post('/auth/otp/send').send({ phone }).expect(200);
      await http()
        .post('/auth/otp/verify')
        .send({ phone, code: DEV_OTP_CODE })
        .expect(200);
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone, code: DEV_OTP_CODE })
        .expect(401);
      expect(res.body.code).toBe('OTP_EXPIRED');
    });

    it('reuses the existing customer on a repeat sign-in', async () => {
      const phone = nextPhone();
      const customerId = (await signInGuest(phone)).customerId;

      // The e2e resend cooldown is 1 second (setup-e2e.ts); wait it out and
      // sign in again — no new customer row may appear.
      await new Promise((resolve) => setTimeout(resolve, 1100));
      const second = await signInGuest(phone);

      expect(second.customerId).toBe(customerId);
      const count = await prisma.customer.count({ where: { phone } });
      expect(count).toBe(1);
    });
  });

  describe('GET /auth/me', () => {
    it('rejects a request without a token (401 UNAUTHORIZED)', async () => {
      const res = await http().get('/auth/me').expect(401);
      expect(res.body.code).toBe('UNAUTHORIZED');
    });

    it('rejects a garbage token (401 TOKEN_INVALID)', async () => {
      const res = await http()
        .get('/auth/me')
        .set('Authorization', 'Bearer garbage')
        .expect(401);
      expect(res.body.code).toBe('TOKEN_INVALID');
    });

    it('rejects a refresh token presented as an access token (401 TOKEN_INVALID)', async () => {
      const phone = nextPhone();
      await http().post('/auth/otp/send').send({ phone }).expect(200);
      const pair = await http()
        .post('/auth/otp/verify')
        .send({ phone, code: DEV_OTP_CODE })
        .expect(200);
      const res = await http()
        .get('/auth/me')
        .set('Authorization', `Bearer ${pair.body.refreshToken}`)
        .expect(401);
      expect(res.body.code).toBe('TOKEN_INVALID');
    });

    it('returns the guest profile for a valid access token', async () => {
      const phone = nextPhone();
      const { token, customerId } = await signInGuest(phone);
      const res = await http()
        .get('/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(res.body).toMatchObject({ id: customerId, phone, role: 'CUSTOMER' });
    });
  });

  describe('GET /orders/my', () => {
    it('rejects a request without a token (401 UNAUTHORIZED)', async () => {
      const res = await http().get('/orders/my').expect(401);
      expect(res.body.code).toBe('UNAUTHORIZED');
    });

    it('rejects a garbage token (401 TOKEN_INVALID)', async () => {
      const res = await http()
        .get('/orders/my')
        .set('Authorization', 'Bearer garbage')
        .expect(401);
      expect(res.body.code).toBe('TOKEN_INVALID');
    });

    it('returns only the caller\'s orders, newest first, with pagination meta', async () => {
      const guestA = await signInGuest(nextPhone());
      const guestB = await signInGuest(nextPhone());

      const orderPayload = {
        type: 'TAKEAWAY',
        brandId,
        branchId,
        items: [{ menuItemId, quantity: 1 }],
      };

      // Two orders for guest A, one for guest B, one anonymous (POS).
      const firstA = await http()
        .post('/orders')
        .set('Authorization', `Bearer ${guestA.token}`)
        .send(orderPayload)
        .expect(201);
      const secondA = await http()
        .post('/orders')
        .set('Authorization', `Bearer ${guestA.token}`)
        .send(orderPayload)
        .expect(201);
      await http()
        .post('/orders')
        .set('Authorization', `Bearer ${guestB.token}`)
        .send(orderPayload)
        .expect(201);
      await http().post('/orders').send(orderPayload).expect(201);

      const mine = await http()
        .get('/orders/my')
        .set('Authorization', `Bearer ${guestA.token}`)
        .expect(200);

      expect(mine.body.meta).toMatchObject({ page: 1, limit: 20, total: 2, totalPages: 1 });
      expect(mine.body.data).toHaveLength(2);
      // Newest first.
      expect(mine.body.data[0].id).toBe(secondA.body.id);
      expect(mine.body.data[1].id).toBe(firstA.body.id);
      expect(
        mine.body.data.every((order: { customerId: string }) => order.customerId === guestA.customerId),
      ).toBe(true);

      // Guest B sees only their own single order.
      const mineB = await http()
        .get('/orders/my')
        .set('Authorization', `Bearer ${guestB.token}`)
        .expect(200);
      expect(mineB.body.meta.total).toBe(1);
      expect(mineB.body.data[0].customerId).toBe(guestB.customerId);
    });

    it('paginates the history (page/limit)', async () => {
      const guest = await signInGuest(nextPhone());
      const orderPayload = {
        type: 'TAKEAWAY',
        brandId,
        branchId,
        items: [{ menuItemId, quantity: 1 }],
      };
      for (let index = 0; index < 3; index += 1) {
        await http()
          .post('/orders')
          .set('Authorization', `Bearer ${guest.token}`)
          .send(orderPayload)
          .expect(201);
      }

      const page1 = await http()
        .get('/orders/my?page=1&limit=2')
        .set('Authorization', `Bearer ${guest.token}`)
        .expect(200);
      expect(page1.body.meta).toMatchObject({ page: 1, limit: 2, total: 3, totalPages: 2 });
      expect(page1.body.data).toHaveLength(2);

      const page2 = await http()
        .get('/orders/my?page=2&limit=2')
        .set('Authorization', `Bearer ${guest.token}`)
        .expect(200);
      expect(page2.body.data).toHaveLength(1);
    });
  });

  describe('guest scoping of /orders', () => {
    it('binds a guest-created order to the customer and scopes GET /orders to that customer', async () => {
      const phoneA = nextPhone();
      const phoneB = nextPhone();
      const guestA = await signInGuest(phoneA);
      const guestB = await signInGuest(phoneB);

      const orderPayload = {
        type: 'TAKEAWAY',
        brandId,
        branchId,
        items: [{ menuItemId, quantity: 1 }],
      };

      // One order per guest + one anonymous (POS) order.
      const orderA = await http()
        .post('/orders')
        .set('Authorization', `Bearer ${guestA.token}`)
        .send(orderPayload)
        .expect(201);
      expect(orderA.body.customerId).toBe(guestA.customerId);

      await http()
        .post('/orders')
        .set('Authorization', `Bearer ${guestB.token}`)
        .send(orderPayload)
        .expect(201);
      await http().post('/orders').send(orderPayload).expect(201);

      // Guest A sees only their own order.
      const listA = await http()
        .get('/orders')
        .set('Authorization', `Bearer ${guestA.token}`)
        .expect(200);
      expect(listA.body.meta.total).toBe(1);
      expect(listA.body.data[0].id).toBe(orderA.body.id);
      expect(listA.body.data[0].customerId).toBe(guestA.customerId);

      // Guest B sees only theirs — guest A's order is invisible.
      const listB = await http()
        .get('/orders')
        .set('Authorization', `Bearer ${guestB.token}`)
        .expect(200);
      expect(listB.body.meta.total).toBe(1);
      expect(listB.body.data[0].customerId).toBe(guestB.customerId);

      // Staff (no token) keeps the unscoped list.
      const listAll = await http().get('/orders').expect(200);
      expect(listAll.body.meta.total).toBeGreaterThanOrEqual(3);
    });

    it('rejects a guest request with an invalid token (401)', async () => {
      await http()
        .get('/orders')
        .set('Authorization', 'Bearer garbage')
        .expect(401);
    });
  });
});
