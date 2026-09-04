import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { INestApplication, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { DEV_OTP_CODE, OTP_TTL_SECONDS } from '../src/modules/auth/auth.config';

/**
 * E2E coverage of the guest auth bounded context (phone + OTP -> JWT):
 *   - POST /auth/otp/send — phone validation, OTP issue (fixed dev code);
 *   - POST /auth/otp/verify — code check, customer auto-provisioning, token pair;
 *   - GET /auth/me — JwtAuthGuard protection of the profile endpoint;
 *   - guest scoping of GET /orders by customerId from the JWT.
 *
 * Runs against DATABASE_URL_TEST (same convention as orders.e2e-spec.ts).
 * No Redis and no SMS_PROVIDER in the test environment: the OTP store is
 * in-memory and the code is the fixed dev code '1234'.
 */

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';

process.env.DATABASE_URL = TEST_DATABASE_URL;
delete process.env.SMS_PROVIDER;
delete process.env.REDIS_URL;
delete process.env.REDIS_HOST;

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

/** Clears every table touched by this spec in FK-safe order. */
async function truncateAll(): Promise<void> {
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

const PHONE_A = '+79991111111';
const PHONE_B = '+79992222222';

/** Registers / re-authenticates a guest and returns the access token + customer id. */
async function signInGuest(phone: string): Promise<{ token: string; customerId: string }> {
  const res = await globalApp
    .post('/auth/otp/send')
    .send({ phone })
    .expect(200);
  expect(res.body.expiresInSeconds).toBe(OTP_TTL_SECONDS);
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
    it('issues an OTP for a valid +7 phone', async () => {
      const res = await http().post('/auth/otp/send').send({ phone: PHONE_A }).expect(200);
      expect(res.body).toEqual({ phone: PHONE_A, expiresInSeconds: OTP_TTL_SECONDS });
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
        .send({ phone: '+79990000000', code: DEV_OTP_CODE })
        .expect(401);
      expect(res.body.code).toBe('OTP_EXPIRED');
    });

    it('rejects a wrong code (401 OTP_INVALID)', async () => {
      await http().post('/auth/otp/send').send({ phone: PHONE_B }).expect(200);
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE_B, code: '0000' })
        .expect(401);
      expect(res.body.code).toBe('OTP_INVALID');
    });

    it('rejects a malformed code with VALIDATION_ERROR', async () => {
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE_B, code: '12ab' })
        .expect(400);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });

    it('verifies the code, auto-creates the customer and returns a token pair', async () => {
      await http().post('/auth/otp/send').send({ phone: PHONE_B }).expect(200);
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE_B, code: DEV_OTP_CODE })
        .expect(200);

      expect(res.body.tokenType).toBe('Bearer');
      expect(res.body.accessToken).toEqual(expect.any(String));
      expect(res.body.refreshToken).toEqual(expect.any(String));
      expect(res.body.expiresInSeconds).toBe(30 * 24 * 60 * 60);
      expect(res.body.customer).toMatchObject({ phone: PHONE_B, name: null, email: null });

      const stored = await prisma.customer.findUnique({ where: { phone: PHONE_B } });
      expect(stored?.id).toBe(res.body.customer.id);
    });

    it('rejects replay of an already verified code (401 OTP_EXPIRED)', async () => {
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE_B, code: DEV_OTP_CODE })
        .expect(401);
      expect(res.body.code).toBe('OTP_EXPIRED');
    });

    it('reuses the existing customer on a repeat sign-in', async () => {
      await http().post('/auth/otp/send').send({ phone: PHONE_B }).expect(200);
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE_B, code: DEV_OTP_CODE })
        .expect(200);

      const count = await prisma.customer.count({ where: { phone: PHONE_B } });
      expect(count).toBe(1);
      // Same customer id as on the first sign-in.
      const first = await prisma.customer.findUnique({ where: { phone: PHONE_B } });
      expect(res.body.customer.id).toBe(first?.id);
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
      await http().post('/auth/otp/send').send({ phone: PHONE_A }).expect(200);
      const pair = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE_A, code: DEV_OTP_CODE })
        .expect(200);
      const res = await http()
        .get('/auth/me')
        .set('Authorization', `Bearer ${pair.body.refreshToken}`)
        .expect(401);
      expect(res.body.code).toBe('TOKEN_INVALID');
    });

    it('returns the guest profile for a valid access token', async () => {
      const { token, customerId } = await signInGuest(PHONE_A);
      const res = await http()
        .get('/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(res.body).toMatchObject({ id: customerId, phone: PHONE_A });
    });
  });

  describe('guest scoping of /orders', () => {
    it('binds a guest-created order to the customer and scopes GET /orders to that customer', async () => {
      const guestA = await signInGuest(PHONE_A);
      const guestB = await signInGuest(PHONE_B);

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
