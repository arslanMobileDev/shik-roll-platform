// Tenant-scoped PIN login, end to end (ADR-1622 step 4b / Step 3 blockers A1-A3).
//
// This is the only suite that runs TWO tenants, and it exists for the one class
// of bug unit tests cannot see: the login key (phone, terminal code) is unique
// per tenant, so "did the right row come back?" is decided by the database
// against a composite key. A mocked Prisma answers whatever the test hands it.
//
// It also carries the behavioural proof for the suspended-tenant fixes: the
// query-shape assertions in the service/guard specs only show the filter was
// passed, not that it filters.
//
// Since ADR-1622 step 5 it owns one more two-tenant job: proving the composite
// FK that makes a cross-tenant (brand, branch) pair impossible to store.
import { execSync } from 'node:child_process';
import type { AddressInfo } from 'node:net';
import * as path from 'node:path';
import {
  BadRequestException,
  INestApplication,
  ValidationPipe,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Prisma, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { KITCHEN_SSE_HEARTBEAT_MS } from '../src/modules/kitchen/kitchen.config';
import { __pinRateLimitResetForTests } from '../src/modules/tenant/pin-rate-limit';

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@localhost:5432/shik_menu_test?schema=public';

process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.DISABLE_QUEUES = 'true';

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

/**
 * The second tenant. The first is the backfilled SHIK_ROLL — resolved by code,
 * never by a hardcoded UUID, which differs between databases.
 */
const TENANT_B = 'TENANT_B_E2E';
const PIN = '1234';
/** Tenant B's PIN for PHONE_STAFF_PIN_ISO — deliberately not PIN. */
const PIN_OTHER = '9876';

/** Same phone in both tenants: the case the composite key exists for. */
const PHONE_STAFF_SHARED = '+79995550101';
/** In tenant A only — the legacy (no header) path must keep working for it. */
const PHONE_STAFF_ONLY_A = '+79995550102';
/** In tenant B only — proves a suspended tenant cannot be reached silently. */
const PHONE_STAFF_ONLY_B = '+79995550103';
const PHONE_COURIER_SHARED = '+79995550104';
/** Courier in tenant A only — the legacy (no header) courier path. */
const PHONE_COURIER_ONLY_A = '+79995550105';
/** Courier in tenant B only — suspended/deleted B must not answer for it. */
const PHONE_COURIER_ONLY_B = '+79995550106';
/** Same phone in both tenants with different PINs — the PIN must be checked
 * against the declared tenant's row, not the first one found. */
const PHONE_STAFF_PIN_ISO = '+79995550107';

const BRAND_A_CODE = 'TA-E2E';
const BRAND_B_CODE = 'TB-E2E';

/** Kitchen terminals, one per tenant — the C4 cross-tenant case. */
const TERMINAL_A_CODE = 'TA-E2E-KDS';
const TERMINAL_B_CODE = 'TB-E2E-KDS';

interface Fixture {
  tenantAId: string;
  tenantBId: string;
  brandAId: string;
  brandBId: string;
  branchAId: string;
  branchBId: string;
  staffSharedAId: string;
  staffSharedBId: string;
  courierSharedAId: string;
  courierSharedBId: string;
  courierOnlyAId: string;
  courierOnlyBId: string;
  staffPinIsoAId: string;
  staffPinIsoBId: string;
  terminalAId: string;
  terminalBId: string;
}

let app: INestApplication;
let fx: Fixture;

/**
 * Removes everything this suite creates, in FK order. The tenant table is not
 * covered by the other suites' truncateAll lists, so a leftover tenant B would
 * survive into the next run and collide on uq_tenants_code — and a leftover
 * brand would trip fk_brands_tenants. Same failure class as Pitfall-021.
 */
async function deleteSuiteRows(tenantBId?: string): Promise<void> {
  const phones = [
    PHONE_STAFF_SHARED,
    PHONE_STAFF_ONLY_A,
    PHONE_STAFF_ONLY_B,
    PHONE_STAFF_PIN_ISO,
    PHONE_COURIER_SHARED,
    PHONE_COURIER_ONLY_A,
    PHONE_COURIER_ONLY_B,
  ];
  // Ahead of brands/branches: a terminal to a deleted branch is an FK error.
  await prisma.kitchenTerminal.deleteMany({
    where: { code: { in: [TERMINAL_A_CODE, TERMINAL_B_CODE] } },
  });
  await prisma.courier.deleteMany({ where: { phone: { in: phones } } });
  await prisma.staff.deleteMany({ where: { phone: { in: phones } } });
  if (tenantBId) {
    await prisma.brandBranch.deleteMany({ where: { brand: { tenantId: tenantBId } } });
  }
  // The rows this suite owns in tenant A are addressed by their brand, since
  // other suites create their own SHIK_ROLL brands.
  const brandAIds = (
    await prisma.brand.findMany({
      where: { code: { in: [BRAND_A_CODE, BRAND_B_CODE] } },
      select: { id: true },
    })
  ).map((b) => b.id);
  if (brandAIds.length > 0) {
    await prisma.brandBranch.deleteMany({ where: { brandId: { in: brandAIds } } });
  }
  await prisma.branch.deleteMany({
    where: { code: { in: ['TA-E2E-01', 'TB-E2E-01'] } },
  });
  await prisma.brand.deleteMany({
    where: { code: { in: [BRAND_A_CODE, BRAND_B_CODE] } },
  });
  await prisma.tenant.deleteMany({ where: { code: TENANT_B } });
}

async function seedFixtures(): Promise<Fixture> {
  const tenantA = await prisma.tenant.findUniqueOrThrow({
    where: { code: 'SHIK_ROLL' },
  });
  const tenantB = await prisma.tenant.create({
    data: { code: TENANT_B, name: 'Tenant B E2E' },
  });

  const brandA = await prisma.brand.create({
    data: { code: BRAND_A_CODE, name: 'Tenant A E2E', tenantId: tenantA.id },
  });
  const brandB = await prisma.brand.create({
    data: { code: BRAND_B_CODE, name: 'Tenant B E2E', tenantId: tenantB.id },
  });
  const branchA = await prisma.branch.create({
    data: { code: 'TA-E2E-01', name: 'Tenant A E2E Branch', tenantId: tenantA.id },
  });
  const branchB = await prisma.branch.create({
    data: { code: 'TB-E2E-01', name: 'Tenant B E2E Branch', tenantId: tenantB.id },
  });
  await prisma.brandBranch.createMany({
    data: [
      { tenantId: tenantA.id, brandId: brandA.id, branchId: branchA.id },
      { tenantId: tenantB.id, brandId: brandB.id, branchId: branchB.id },
    ],
  });

  const pinHash = await bcrypt.hash(PIN, 4);
  const staffSharedA = await prisma.staff.create({
    data: {
      tenantId: tenantA.id,
      brandId: brandA.id,
      name: 'Staff shared A',
      phone: PHONE_STAFF_SHARED,
      pinHash,
      role: 'MANAGER',
    },
  });
  const staffSharedB = await prisma.staff.create({
    data: {
      tenantId: tenantB.id,
      brandId: brandB.id,
      name: 'Staff shared B',
      phone: PHONE_STAFF_SHARED,
      pinHash,
      role: 'MANAGER',
    },
  });
  await prisma.staff.create({
    data: {
      tenantId: tenantA.id,
      brandId: brandA.id,
      name: 'Staff only A',
      phone: PHONE_STAFF_ONLY_A,
      pinHash,
      role: 'MANAGER',
    },
  });
  await prisma.staff.create({
    data: {
      tenantId: tenantB.id,
      brandId: brandB.id,
      name: 'Staff only B',
      phone: PHONE_STAFF_ONLY_B,
      pinHash,
      role: 'MANAGER',
    },
  });

  const courierSharedA = await prisma.courier.create({
    data: {
      tenantId: tenantA.id,
      brandId: brandA.id,
      branchId: branchA.id,
      name: 'Courier shared A',
      phone: PHONE_COURIER_SHARED,
      pinHash,
    },
  });
  const courierSharedB = await prisma.courier.create({
    data: {
      tenantId: tenantB.id,
      brandId: brandB.id,
      branchId: branchB.id,
      name: 'Courier shared B',
      phone: PHONE_COURIER_SHARED,
      pinHash,
    },
  });
  const courierOnlyA = await prisma.courier.create({
    data: {
      tenantId: tenantA.id,
      brandId: brandA.id,
      branchId: branchA.id,
      name: 'Courier only A',
      phone: PHONE_COURIER_ONLY_A,
      pinHash,
    },
  });
  const courierOnlyB = await prisma.courier.create({
    data: {
      tenantId: tenantB.id,
      brandId: brandB.id,
      branchId: branchB.id,
      name: 'Courier only B',
      phone: PHONE_COURIER_ONLY_B,
      pinHash,
    },
  });

  const staffPinIsoA = await prisma.staff.create({
    data: {
      tenantId: tenantA.id,
      brandId: brandA.id,
      name: 'Staff pin isolation A',
      phone: PHONE_STAFF_PIN_ISO,
      pinHash,
      role: 'MANAGER',
    },
  });
  const staffPinIsoB = await prisma.staff.create({
    data: {
      tenantId: tenantB.id,
      brandId: brandB.id,
      name: 'Staff pin isolation B',
      phone: PHONE_STAFF_PIN_ISO,
      pinHash: await bcrypt.hash(PIN_OTHER, 4),
      role: 'MANAGER',
    },
  });

  const terminalA = await prisma.kitchenTerminal.create({
    data: {
      code: TERMINAL_A_CODE,
      name: 'Tenant A E2E KDS',
      pinHash,
      branchId: branchA.id,
      tenantId: tenantA.id,
    },
  });
  const terminalB = await prisma.kitchenTerminal.create({
    data: {
      code: TERMINAL_B_CODE,
      name: 'Tenant B E2E KDS',
      pinHash,
      branchId: branchB.id,
      tenantId: tenantB.id,
    },
  });

  return {
    tenantAId: tenantA.id,
    tenantBId: tenantB.id,
    brandAId: brandA.id,
    brandBId: brandB.id,
    branchAId: branchA.id,
    branchBId: branchB.id,
    staffSharedAId: staffSharedA.id,
    staffSharedBId: staffSharedB.id,
    courierSharedAId: courierSharedA.id,
    courierSharedBId: courierSharedB.id,
    courierOnlyAId: courierOnlyA.id,
    courierOnlyBId: courierOnlyB.id,
    staffPinIsoAId: staffPinIsoA.id,
    staffPinIsoBId: staffPinIsoB.id,
    terminalAId: terminalA.id,
    terminalBId: terminalB.id,
  };
}

const loginStaff = (phone: string, tenantCode?: string, pin: string = PIN) => {
  const req = request(app.getHttpServer()).post('/staff/auth/pin');
  return (tenantCode ? req.set('X-Tenant', tenantCode) : req).send({
    phone,
    pin,
  });
};

const loginCourier = (phone: string, tenantCode?: string, pin: string = PIN) => {
  const req = request(app.getHttpServer()).post('/couriers/auth/pin');
  return (tenantCode ? req.set('X-Tenant', tenantCode) : req).send({
    phone,
    pin,
  });
};

const setTenantB = (data: { status?: string; deletedAt?: Date | null }) =>
  prisma.tenant.update({ where: { id: fx.tenantBId }, data });

/** Rejects instead of hanging the suite when the awaited event never comes. */
function withDeadline<T>(work: Promise<T>, ms: number, what: string): Promise<T> {
  return Promise.race([
    work,
    new Promise<never>((_, reject) =>
      setTimeout(
        () => reject(new Error(`Timed out after ${ms}ms waiting for ${what}`)),
        ms,
      ).unref(),
    ),
  ]);
}

/** Reads the body until the server ends the response. */
async function drain(reader: {
  read(): Promise<{ done: boolean }>;
}): Promise<void> {
  for (;;) {
    const { done } = await reader.read();
    if (done) {
      return;
    }
  }
}

describe('tenant-scoped PIN login (ADR-1622 step 4b)', () => {
  beforeAll(async () => {
    execSync('pnpm prisma migrate deploy', {
      cwd: path.resolve(__dirname, '..'),
      env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
      stdio: 'inherit',
    });
    // A previous failed run may have left tenant B behind.
    const stale = await prisma.tenant.findUnique({ where: { code: TENANT_B } });
    await deleteSuiteRows(stale?.id);
    fx = await seedFixtures();

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
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
  });

  // Several tests suspend or soft-delete tenant B, or deactivate a courier;
  // none of them should be able to leak that state into the next one.
  afterEach(async () => {
    // The limiter's Map is module state: without this, the 401s of one test
    // become the 429 of the next.
    __pinRateLimitResetForTests();
    await setTenantB({ status: 'ACTIVE', deletedAt: null });
    await prisma.courier.updateMany({
      where: { phone: { in: [PHONE_COURIER_ONLY_A, PHONE_COURIER_SHARED] } },
      data: { isActive: true },
    });
    await prisma.staff.updateMany({
      where: { phone: PHONE_STAFF_SHARED },
      data: { isActive: true },
    });
  });

  afterAll(async () => {
    await app?.close();
    await deleteSuiteRows(fx?.tenantBId);
    await prisma.$disconnect();
  });

  describe('with a declared tenant', () => {
    it('resolves a phone that exists in both tenants to the declared one', async () => {
      const inA = await loginStaff(PHONE_STAFF_SHARED, 'SHIK_ROLL').expect(200);
      expect(inA.body.staff.id).toBe(fx.staffSharedAId);

      // Lowercase on purpose: the middleware uppercases the code.
      const inB = await loginStaff(PHONE_STAFF_SHARED, TENANT_B.toLowerCase());
      expect(inB.status).toBe(200);
      expect(inB.body.staff.id).toBe(fx.staffSharedBId);
    });

    it('resolves a courier phone that exists in both tenants to the declared one', async () => {
      const inA = await loginCourier(PHONE_COURIER_SHARED, 'SHIK_ROLL').expect(200);
      expect(inA.body.courier.id).toBe(fx.courierSharedAId);

      const inB = await loginCourier(PHONE_COURIER_SHARED, TENANT_B).expect(200);
      expect(inB.body.courier.id).toBe(fx.courierSharedBId);
    });

    it('checks the PIN against the declared tenant row, not the other one', async () => {
      // Same phone in A and B with different PINs: each tenant's own hash is
      // the only accepted one, and the row resolved is the declared one.
      const inA = await loginStaff(PHONE_STAFF_PIN_ISO, 'SHIK_ROLL', PIN).expect(200);
      expect(inA.body.staff.id).toBe(fx.staffPinIsoAId);

      const inB = await loginStaff(PHONE_STAFF_PIN_ISO, TENANT_B, PIN_OTHER).expect(200);
      expect(inB.body.staff.id).toBe(fx.staffPinIsoBId);

      const crossed = await loginStaff(PHONE_STAFF_PIN_ISO, 'SHIK_ROLL', PIN_OTHER).expect(401);
      expect(crossed.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('does not fall back to another tenant that owns the phone', async () => {
      // PHONE_STAFF_ONLY_B lives in B only: declaring A must answer "no such
      // account", never resolve B's row.
      const res = await loginStaff(PHONE_STAFF_ONLY_B, 'SHIK_ROLL').expect(401);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('takes ?tenant=CODE as the fallback when no header is sent', async () => {
      const res = await request(app.getHttpServer())
        .post('/staff/auth/pin')
        .query({ tenant: 'SHIK_ROLL' })
        .send({ phone: PHONE_STAFF_SHARED, pin: PIN })
        .expect(200);
      expect(res.body.staff.id).toBe(fx.staffSharedAId);
    });
  });

  describe('without a declared tenant (clients that predate the header)', () => {
    it('still logs in when exactly one tenant owns the phone', async () => {
      const res = await loginStaff(PHONE_STAFF_ONLY_A).expect(200);
      expect(res.body.staff.id).toBeTruthy();
    });

    it('answers 409 AMBIGUOUS_TENANT when several active tenants own it', async () => {
      const res = await loginStaff(PHONE_STAFF_SHARED).expect(409);
      expect(res.body.code).toBe('AMBIGUOUS_TENANT');
    });

    it('answers 409 even when one of the two accounts is deactivated', async () => {
      // Accepted behaviour (ADR-1622): the ambiguity is answered before the PIN
      // is checked, so the client cannot tell "the other account is unusable"
      // from "the other account is fine" — deliberate, and pinned here.
      await prisma.staff.updateMany({
        where: { phone: PHONE_STAFF_SHARED, tenantId: fx.tenantBId },
        data: { isActive: false },
      });

      const res = await loginStaff(PHONE_STAFF_SHARED).expect(409);
      expect(res.body.code).toBe('AMBIGUOUS_TENANT');
      expect(res.body.token).toBeUndefined();
    });

    it('does not treat a suspended tenant as the other candidate', async () => {
      // A owns the phone and is active, B owns it and is not: the answer IS
      // knowable, so this must resolve rather than answer 409.
      await setTenantB({ status: 'SUSPENDED' });

      const res = await loginStaff(PHONE_STAFF_SHARED).expect(200);
      expect(res.body.staff.id).toBe(fx.staffSharedAId);
    });
  });

  describe('courier login without a declared tenant', () => {
    it('still logs in when exactly one tenant owns the phone', async () => {
      const res = await loginCourier(PHONE_COURIER_ONLY_A).expect(200);
      expect(res.body.courier.id).toBe(fx.courierOnlyAId);
      expect(res.body.token).toBeTruthy();
    });

    it('answers 409 AMBIGUOUS_TENANT when several active tenants own it', async () => {
      const res = await loginCourier(PHONE_COURIER_SHARED).expect(409);
      expect(res.body.code).toBe('AMBIGUOUS_TENANT');
    });

    it('rejects a courier whose account is deactivated, without a token', async () => {
      // The status may be the same 401 as an unknown phone — what matters is
      // that no token is minted for a deactivated account on this path.
      await prisma.courier.updateMany({
        where: { phone: PHONE_COURIER_ONLY_A },
        data: { isActive: false },
      });

      const res = await loginCourier(PHONE_COURIER_ONLY_A).expect(401);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
      expect(res.body.token).toBeUndefined();
    });
  });

  describe('suspended tenant', () => {
    it('rejects a login that declares no tenant (401, not 200)', async () => {
      await setTenantB({ status: 'SUSPENDED' });

      const res = await loginStaff(PHONE_STAFF_ONLY_B).expect(401);
      // Uniform with "no such account": nothing here says the tenant exists.
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('rejects a courier login that declares no tenant (401, not 200)', async () => {
      await setTenantB({ status: 'SUSPENDED' });

      const res = await loginCourier(PHONE_COURIER_ONLY_B).expect(401);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('rejects a login that names the tenant explicitly (403 TENANT_SUSPENDED)', async () => {
      await setTenantB({ status: 'SUSPENDED' });

      const res = await loginStaff(PHONE_STAFF_SHARED, TENANT_B).expect(403);
      expect(res.body.code).toBe('TENANT_SUSPENDED');
    });

    it('filters the composite-key row lookup in the database, not only in the query shape', async () => {
      // ORM-contract check, not app behaviour: this is the exact `where` the
      // scoped login sends. The unit specs assert that the filter is *passed*;
      // only this shows the database applies it — the property both the login
      // lookups and the JWT guards depend on.
      const where = {
        tenantId_phone: { tenantId: fx.tenantBId, phone: PHONE_STAFF_SHARED },
        tenant: { status: 'ACTIVE', deletedAt: null },
      };
      await expect(prisma.staff.findUnique({ where })).resolves.toMatchObject({
        id: fx.staffSharedBId,
      });

      await setTenantB({ status: 'SUSPENDED' });
      await expect(prisma.staff.findUnique({ where })).resolves.toBeNull();
    });

    it('invalidates tokens issued before the suspension', async () => {
      const login = await loginStaff(PHONE_STAFF_SHARED, TENANT_B).expect(200);
      const token = login.body.token;

      await request(app.getHttpServer())
        .get('/staff/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      await setTenantB({ status: 'SUSPENDED' });

      const blocked = await request(app.getHttpServer())
        .get('/staff/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
      expect(blocked.body.code).toBe('TOKEN_INVALID');

      // Same token, same tenant, only the status restored.
      await setTenantB({ status: 'ACTIVE' });
      await request(app.getHttpServer())
        .get('/staff/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
    });

    it('invalidates a courier token issued before the suspension', async () => {
      const login = await loginCourier(PHONE_COURIER_SHARED, TENANT_B).expect(200);
      const token = login.body.token;

      await request(app.getHttpServer())
        .get('/couriers/orders/active')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      await setTenantB({ status: 'SUSPENDED' });

      const blocked = await request(app.getHttpServer())
        .get('/couriers/orders/active')
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
      expect(blocked.body.code).toBe('TOKEN_INVALID');
    });
  });

  describe('soft-deleted tenant', () => {
    it('answers 404 TENANT_NOT_FOUND, exactly like a tenant that never existed', async () => {
      await setTenantB({ deletedAt: new Date() });

      const res = await loginStaff(PHONE_STAFF_SHARED, TENANT_B).expect(404);
      expect(res.body.code).toBe('TENANT_NOT_FOUND');
    });

    it('cannot be reached by omitting the header either', async () => {
      await setTenantB({ deletedAt: new Date() });

      const res = await loginStaff(PHONE_STAFF_ONLY_B).expect(401);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('cannot be reached by a courier login either', async () => {
      await setTenantB({ deletedAt: new Date() });

      const res = await loginCourier(PHONE_COURIER_ONLY_B).expect(401);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('invalidates a staff token issued before the deletion', async () => {
      // Issued while B is still active, then B is soft-deleted.
      const login = await loginStaff(PHONE_STAFF_SHARED, TENANT_B).expect(200);
      const token = login.body.token;

      await setTenantB({ deletedAt: new Date() });

      const blocked = await request(app.getHttpServer())
        .get('/staff/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
      expect(blocked.body.code).toBe('TOKEN_INVALID');
    });

    it('invalidates a courier token issued before the deletion', async () => {
      const login = await loginCourier(PHONE_COURIER_SHARED, TENANT_B).expect(200);
      const token = login.body.token;

      await setTenantB({ deletedAt: new Date() });

      const blocked = await request(app.getHttpServer())
        .get('/couriers/orders/active')
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
      expect(blocked.body.code).toBe('TOKEN_INVALID');
    });
  });

  // ADR-1622 step 5. The pair (brand, branch) used to be three independently
  // valid ids: orders had single-column FKs, couriers had none, and nothing
  // forced brand and branch into one tenant. These two tests are the DB-level
  // contract — a direct write, not HTTP, because the constraint has to hold for
  // every writer, including the ones that skip the service layer.
  describe('cross-tenant brand/branch pair', () => {
    /**
     * Runs the insert inside a transaction that always rolls back, so neither
     * test leaves a row behind for the next suite (Pitfall-021 class: a leaked
     * order blocks brand_branches/branch deletes in afterAll). The sentinel
     * error means "the insert was accepted"; a constraint violation surfaces as
     * P2003 instead and never reaches the sentinel.
     */
    const insertThenRollBack = (insert: (tx: Prisma.TransactionClient) => Promise<unknown>) =>
      prisma.$transaction(async (tx) => {
        await insert(tx);
        throw new Error('ROLLBACK_PROBE');
      });

    const order = (brandId: string, branchId: string) => (tx: Prisma.TransactionClient) =>
      tx.order.create({
        data: {
          orderNumber: 'XTEN-1',
          type: 'TAKEAWAY',
          tenantId: fx.tenantAId,
          brandId,
          branchId,
        },
      });

    const courier = (brandId: string, branchId: string) => (tx: Prisma.TransactionClient) =>
      tx.courier.create({
        data: {
          tenantId: fx.tenantAId,
          name: 'Cross probe',
          phone: '+79995550199',
          pinHash: 'probe',
          brandId,
          branchId,
        },
      });

    it('accepts the pair within one tenant (control for the two tests below)', async () => {
      // Without this, a fixture that linked no pair at all would make the
      // rejections below pass for the wrong reason.
      await expect(insertThenRollBack(order(fx.brandAId, fx.branchAId))).rejects.toThrow(
        'ROLLBACK_PROBE',
      );
      await expect(insertThenRollBack(courier(fx.brandAId, fx.branchAId))).rejects.toThrow(
        'ROLLBACK_PROBE',
      );
    });

    it('rejects an order whose brand is tenant A and branch is tenant B', async () => {
      await expect(insertThenRollBack(order(fx.brandAId, fx.branchBId))).rejects.toMatchObject({
        code: 'P2003',
      });
    });

    it('rejects a courier whose brand is tenant A and branch is tenant B', async () => {
      await expect(insertThenRollBack(courier(fx.brandAId, fx.branchBId))).rejects.toMatchObject({
        code: 'P2003',
      });
    });
  });

  describe('Kitchen PIN rate-limit across tenants', () => {
    const loginKitchen = (
      terminalCode: string,
      tenantCode: string,
      pin: string,
    ) =>
      request(app.getHttpServer())
        .post('/kitchen/auth/pin')
        .set('X-Tenant', tenantCode)
        .send({ terminalCode, pin });

    it('locks out the flooded tenant without touching the other', async () => {
      for (let i = 0; i < 5; i += 1) {
        await loginKitchen(TERMINAL_A_CODE, 'SHIK_ROLL', '0000').expect(401);
      }

      // The sixth carries the *correct* PIN: the 429 is answered before the
      // credential is looked at, which is the whole point of counting every
      // attempt rather than only the failures.
      const blocked = await loginKitchen(TERMINAL_A_CODE, 'SHIK_ROLL', PIN).expect(429);
      expect(blocked.body.code).toBe('TOO_MANY_ATTEMPTS');
      // The header is the machine-readable half of the answer.
      expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(0);

      // Tenant B's budget is its own: the same attempt there is a plain 401.
      const other = await loginKitchen(TERMINAL_B_CODE, TENANT_B, '0000').expect(401);
      expect(other.body.code).toBe('UNAUTHORIZED');
    });

    it('clears the counter on a successful login', async () => {
      for (let i = 0; i < 4; i += 1) {
        await loginKitchen(TERMINAL_A_CODE, 'SHIK_ROLL', '0000').expect(401);
      }

      const ok = await loginKitchen(TERMINAL_A_CODE, 'SHIK_ROLL', PIN).expect(200);
      expect(ok.body.terminal.id).toBe(fx.terminalAId);

      // Five more failures. Without the reset the counter would already be at
      // four and the second of these would answer 429.
      for (let i = 0; i < 5; i += 1) {
        await loginKitchen(TERMINAL_A_CODE, 'SHIK_ROLL', '0000').expect(401);
      }
    });
  });

  describe('SSE stream ends with its tenant (ADR-1622 C5)', () => {
    /**
     * The one thing the service spec cannot show: that ending the Observable
     * reaches the socket. There, takeUntil proves the guard emits; here a
     * suspended tenant must actually read EOF instead of a stream that keeps
     * heartbeating.
     *
     * supertest has no SSE mode (its request only settles when the response
     * ends), so the same server is driven with fetch and the body stream is
     * read directly.
     */
    it('closes the kitchen stream within a tick of the tenant leaving ACTIVE', async () => {
      const login = await request(app.getHttpServer())
        .post('/kitchen/auth/pin')
        .set('X-Tenant', TENANT_B)
        .send({ terminalCode: TERMINAL_B_CODE, pin: PIN })
        .expect(200);

      const server = app.getHttpServer();
      if (!server.listening) {
        await new Promise<void>((resolve) => server.listen(0, resolve));
      }
      const { port } = server.address() as AddressInfo;

      const res = await fetch(`http://127.0.0.1:${port}/kitchen/stream`, {
        headers: {
          Authorization: `Bearer ${login.body.token}`,
          Accept: 'text/event-stream',
        },
      });
      expect(res.status).toBe(200);

      const reader = res.body!.getReader();
      const decoder = new TextDecoder();
      try {
        // While ACTIVE the heartbeat arrives on its own cadence, which also
        // rules out a stream that closes on every request regardless.
        let received = '';
        while (!received.includes('heartbeat')) {
          const chunk = await withDeadline(reader.read(), 5_000, 'a heartbeat');
          expect(chunk.done).toBe(false);
          received += decoder.decode(chunk.value, { stream: true });
        }

        await setTenantB({ status: 'SUSPENDED' });

        // Two guard ticks plus slack: one tick to notice, one for the DB read
        // and the response teardown. The budget covers the whole wait rather
        // than each read — heartbeats keep arriving while the stream is open,
        // so a per-read deadline would never expire.
        await withDeadline(
          drain(reader),
          2 * KITCHEN_SSE_HEARTBEAT_MS + 3_000,
          'the stream to end',
        );
      } finally {
        // A failed assertion above must not leave a live connection behind.
        await reader.cancel().catch(() => undefined);
      }
    });
  });
});

describe('TenantMiddleware — transport-level strictness (ADR-1622 C2)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  const http = () => request(app.getHttpServer());

  it('rejects a comma-glued X-Tenant (state after Node de-dupe) — 400 TENANT_INVALID', async () => {
    // Supertest's .set() overwrites same-name headers, so it cannot send two
    // physical X-Tenant fields. Node would glue those into "A, B" before the
    // middleware sees them; we emulate that exact state here. The raw-header
    // detection of the two-field case is covered by the unit spec.
    const res = await http()
      .get('/health/live')
      .set('X-Tenant', 'A, B')
      .expect(400);
    expect(res.body.code).toBe('TENANT_INVALID');
  });

  it('rejects ?tenant[a]=b with 400 TENANT_INVALID', async () => {
    const res = await http()
      .get('/health/live?tenant[a]=b')
      .expect(400);
    expect(res.body.code).toBe('TENANT_INVALID');
  });

  it('rejects ?tenant[]=A with 400 TENANT_INVALID', async () => {
    const res = await http()
      .get('/health/live?tenant[]=A')
      .expect(400);
    expect(res.body.code).toBe('TENANT_INVALID');
  });

  it('rejects ?tenant=A&tenant=B with 400 TENANT_INVALID', async () => {
    const res = await http()
      .get('/health/live?tenant=A&tenant=B')
      .expect(400);
    expect(res.body.code).toBe('TENANT_INVALID');
  });

  it('passes /health/live without any tenant declaration', async () => {
    await http().get('/health/live').expect(200);
  });
});
