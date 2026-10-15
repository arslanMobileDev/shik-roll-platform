import { execSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import * as path from 'node:path';
import { INestApplication, ValidationPipe, BadRequestException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { OrderStatus, PrismaClient } from '@prisma/client';
import { Queue } from 'bullmq';
import * as bcrypt from 'bcryptjs';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { COURIER_RESTORE_WINDOW_DAYS } from '../src/modules/couriers/couriers.config';
import { CourierMaintenanceProcessor } from '../src/modules/queues/courier-maintenance.processor';
import { PrismaService } from '../src/prisma/prisma.service';

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
  tenantId: string;
  brandId: string;
  branchId: string;
  courierId: string;
  courierPhone: string;
  courierPin: string;
}

async function seedFixtures(): Promise<Fixture> {
  // ADR-1622: tenant #1 comes from the backfill migration, so it is resolved by
  // code — the UUID is minted per database.
  const tenant = await prisma.tenant.findUniqueOrThrow({ where: { code: 'SHIK_ROLL' } });
  const brand = await prisma.brand.create({
    data: { code: 'COURIER_E2E', name: 'Courier E2E', tenantId: tenant.id },
  });
  const branch = await prisma.branch.create({
    data: { code: 'C-E2E-01', name: 'Courier E2E Branch', tenantId: tenant.id },
  });
  await prisma.brandBranch.create({
    data: { tenantId: tenant.id, brandId: brand.id, branchId: branch.id },
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
      tenantId: tenant.id,
      isActive: true,
      isAvailable: true,
    },
  });

  return {
    tenantId: tenant.id,
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
      .expect(200);
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
        tenantId: fx.tenantId,
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

  describe('GET /couriers/orders/history', () => {
    it('401 without token', async () => {
      await http().get('/couriers/orders/history').expect(401);
    });

    it('returns empty page for a fresh courier', async () => {
      const res = await http()
        .get('/couriers/orders/history')
        .set('Authorization', `Bearer ${courierToken}`)
        .expect(200);
      expect(res.body.data).toEqual([]);
      expect(res.body.meta.total).toBe(0);
    });

    it('returns own COMPLETED order, excludes active and foreign', async () => {
      const completed = await createOrderInStatus(OrderStatus.COMPLETED, {
        courierId: fx.courierId,
      });
      await prisma.order.update({
        where: { id: completed },
        data: { completedAt: new Date('2026-09-15T12:00:00Z') },
      });

      await createOrderInStatus(OrderStatus.ON_WAY, { courierId: fx.courierId });
      await createOrderInStatus(OrderStatus.COMPLETED, { courierId: null });

      const res = await http()
        .get('/couriers/orders/history')
        .set('Authorization', `Bearer ${courierToken}`)
        .expect(200);

      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].id).toBe(completed);
      expect(res.body.meta).toMatchObject({ page: 1, limit: 20, total: 1, totalPages: 1 });
    });

    it('returns CANCELLED orders as well', async () => {
      const cancelled = await createOrderInStatus(OrderStatus.CANCELLED, {
        courierId: fx.courierId,
      });
      await prisma.order.update({
        where: { id: cancelled },
        data: { cancelledAt: new Date('2026-09-20T10:00:00Z') },
      });

      const res = await http()
        .get('/couriers/orders/history')
        .set('Authorization', `Bearer ${courierToken}`)
        .expect(200);
      expect(res.body.data.map((o: any) => o.id)).toEqual([cancelled]);
    });

    it('honours from/to bounds on completedAt', async () => {
      const older = await createOrderInStatus(OrderStatus.COMPLETED, {
        courierId: fx.courierId,
      });
      await prisma.order.update({
        where: { id: older },
        data: { completedAt: new Date('2026-08-01T10:00:00Z') },
      });
      const newer = await createOrderInStatus(OrderStatus.COMPLETED, {
        courierId: fx.courierId,
      });
      await prisma.order.update({
        where: { id: newer },
        data: { completedAt: new Date('2026-09-15T10:00:00Z') },
      });

      const res = await http()
        .get('/couriers/orders/history?from=2026-09-01T00:00:00Z&to=2026-09-30T23:59:59Z')
        .set('Authorization', `Bearer ${courierToken}`)
        .expect(200);
      expect(res.body.data.map((o: any) => o.id)).toEqual([newer]);
    });
  });

  /**
   * Apple 5.1.1(v) self-service deletion.
   *
   * Declared last on purpose: the success case deletes the fixture courier for
   * good, so every test above has to have run by then. The non-destructive
   * cases come first and assert the account is untouched, which is what keeps
   * this ordering honest rather than merely convenient.
   */
  describe('POST /couriers/me/delete', () => {
    const deleteAccount = (pin: string, token?: string) => {
      const req = http().post('/couriers/me/delete').send({ pin });
      if (token) req.set('Authorization', `Bearer ${token}`);
      return req;
    };

    const readCourier = () =>
      prisma.courier.findUniqueOrThrow({ where: { id: fx.courierId } });

    it('401 without a token', async () => {
      await deleteAccount(fx.courierPin).expect(401);
    });

    it('401 on a wrong PIN, leaving the account untouched', async () => {
      await deleteAccount('9999', courierToken).expect(401);

      const courier = await readCourier();
      expect(courier.phone).toBe(fx.courierPhone);
      expect(courier.name).toBe('Courier E2E');
      expect(courier.isActive).toBe(true);
      expect(courier.deletedAt).toBeNull();
    });

    it('409 ACTIVE_ORDERS_EXIST while a READY order is held', async () => {
      await createOrderInStatus(OrderStatus.READY, { courierId: fx.courierId });

      const res = await deleteAccount(fx.courierPin, courierToken).expect(409);
      expect(res.body.code).toBe('ACTIVE_ORDERS_EXIST');

      expect((await readCourier()).isActive).toBe(true);
    });

    it('an unassigned COOKING order of the branch does not block deletion', async () => {
      // Nobody owns it yet, so holding it hostage would strand the account.
      await createOrderInStatus(OrderStatus.COOKING);

      await deleteAccount('9999', courierToken).expect(401);
    });

    it('deletes: flags the row, keeps the data and revokes access', async () => {
      const res = await deleteAccount(fx.courierPin, courierToken).expect(200);
      expect(res.body).toEqual({ deleted: true });

      const courier = await readCourier();
      // Kept on purpose — the 7-day restore window hands the account back
      // whole, so everything a restored courier needs has to still be here.
      expect(courier.name).toBe('Courier E2E');
      expect(courier.phone).toBe(fx.courierPhone);
      expect(courier.isActive).toBe(false);
      expect(courier.deletedAt).toBeInstanceOf(Date);
      // Untouched: availability is the courier's own shift toggle, not part of
      // the deletion, and restore must not have to reset it.
      expect(courier.isAvailable).toBe(true);

      // The phone still resolves — this 401 is the deletedAt filter in the
      // lookup, not a missing number, which is the whole reason the guard needs
      // its own deletedAt arm.
      await http()
        .post('/couriers/auth/pin')
        .send({ phone: fx.courierPhone, pin: fx.courierPin })
        .expect(401);

      // And the still-valid JWT dies with the row: the guard re-reads it on
      // every request, which is what makes deletion actually revoke access.
      await http()
        .get('/couriers/orders/active')
        .set('Authorization', `Bearer ${courierToken}`)
        .expect(401);
    });

    it('releases the phone for a new courier', async () => {
      // The deleted row still holds the number, so this insert only succeeds
      // because uq_couriers_tenant_id_phone is partial (deleted_at IS NULL).
      // The unique slot is also only genuinely free if this insert succeeds; a
      // 'deleted:<uuid>' tombstone would have made it fail with P2002.
      const replacement = await prisma.courier.create({
        data: {
          name: 'Replacement Courier',
          phone: fx.courierPhone,
          pinHash: await bcrypt.hash('4321', 4),
          brandId: fx.brandId,
          branchId: fx.branchId,
          tenantId: fx.tenantId,
        },
      });
      expect(replacement.id).not.toBe(fx.courierId);

      await http()
        .post('/couriers/auth/pin')
        .send({ phone: fx.courierPhone, pin: '4321' })
        .expect(200);
    });
  });

  /**
   * The other half of Apple 5.1.1(v): the deletion has to be survivable, or a
   * mis-tap costs the account, the PIN and the delivery history.
   *
   * Declared after the delete block, which leaves exactly the state a restore
   * has to cope with: a deleted row inside its window AND a live replacement
   * holding the same number.
   */
  describe('POST /couriers/auth/restore', () => {
    const restore = (phone: string, pin: string) =>
      http().post('/couriers/auth/restore').send({ phone, pin });

    const readCourier = () =>
      prisma.courier.findUniqueOrThrow({ where: { id: fx.courierId } });

    it('401 on an unknown phone', async () => {
      await restore('+70000000000', fx.courierPin).expect(401);
    });

    it('401 on a wrong PIN, leaving the row deleted', async () => {
      await restore(fx.courierPhone, '9999').expect(401);

      const courier = await readCourier();
      expect(courier.deletedAt).toBeInstanceOf(Date);
      expect(courier.isActive).toBe(false);
      expect(courier.phone).toBe(fx.courierPhone);
    });

    it('409 COURIER_PHONE_EXISTS when the number has been re-issued', async () => {
      // The delete block's replacement holds this number live, which is the one
      // thing the partial unique index forbids a restore from doing. The
      // database is the guard here, not a count before the write.
      const res = await restore(fx.courierPhone, fx.courierPin).expect(409);
      expect(res.body.code).toBe('COURIER_PHONE_EXISTS');

      expect((await readCourier()).deletedAt).toBeInstanceOf(Date);
    });

    it('restores the account whole and issues a session that works', async () => {
      // Drop the replacement: one live row per number is the invariant the
      // previous test proved the restore respects.
      await prisma.courier.deleteMany({
        where: { phone: fx.courierPhone, deletedAt: null },
      });

      const res = await restore(fx.courierPhone, fx.courierPin).expect(200);
      expect(res.body.tokenType).toBe('Bearer');
      expect(res.body.courier).toEqual({
        id: fx.courierId,
        name: 'Courier E2E',
        phone: fx.courierPhone,
      });

      const courier = await readCourier();
      expect(courier.deletedAt).toBeNull();
      expect(courier.isActive).toBe(true);
      // Everything the deletion kept is what made this whole: the real name,
      // the login number, the PIN, and the shift toggle that was never part of
      // the deletion.
      expect(courier.name).toBe('Courier E2E');
      expect(courier.phone).toBe(fx.courierPhone);
      expect(courier.isAvailable).toBe(true);

      // The PIN logs in again, and the session handed back by the restore is
      // accepted by the guard the deletion used to reject.
      await http()
        .post('/couriers/auth/pin')
        .send({ phone: fx.courierPhone, pin: fx.courierPin })
        .expect(200);
      await http()
        .get('/couriers/orders/active')
        .set('Authorization', `Bearer ${res.body.token}`)
        .expect(200);
    });

    it('401 once the window has closed, leaving the row deleted', async () => {
      // Backdate the deletion past the window rather than waiting 7 days:
      // COURIER_RESTORE_WINDOW_DAYS is a product constant, not env tuning.
      await prisma.courier.update({
        where: { id: fx.courierId },
        data: {
          isActive: false,
          deletedAt: new Date(
            Date.now() - (COURIER_RESTORE_WINDOW_DAYS + 1) * 24 * 60 * 60 * 1000,
          ),
        },
      });

      await restore(fx.courierPhone, fx.courierPin).expect(401);

      const courier = await readCourier();
      expect(courier.deletedAt).toBeInstanceOf(Date);
      expect(courier.isActive).toBe(false);
    });
  });

  /**
   * The sweep is driven directly rather than through BullMQ: every e2e spec runs
   * with DISABLE_QUEUES, so no worker is registered and no scheduler ever fires.
   * What this covers is the sweep against a real database — where the window
   * boundary falls, and what burning a courier does to the deliveries that point
   * at it.
   */
  describe('expiry sweep (courier-maintenance)', () => {
    const sweep = new CourierMaintenanceProcessor(
      prisma as unknown as PrismaService,
      { upsertJobScheduler: async () => ({ id: 'unused' }) } as unknown as Queue,
    );

    const createCourierDeletedDaysAgo = async (phone: string, daysAgo: number | null) =>
      prisma.courier.create({
        data: {
          name: `Sweep ${phone}`,
          phone,
          pinHash: await bcrypt.hash('1234', 4),
          brandId: fx.brandId,
          branchId: fx.branchId,
          tenantId: fx.tenantId,
          // isActive false either way — a self-deleted row and a staff block look
          // the same here. deletedAt is what separates them.
          isActive: false,
          deletedAt:
            daysAgo === null ? null : new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000),
        },
      });

    it('burns the expired account, keeps the one inside the window, and leaves the delivery standing', async () => {
      const expired = await createCourierDeletedDaysAgo(
        '+79995550090',
        COURIER_RESTORE_WINDOW_DAYS + 1,
      );
      const insideWindow = await createCourierDeletedDaysAgo('+79995550091', 1);
      const orderId = await createOrderInStatus(OrderStatus.COMPLETED, {
        courierId: expired.id,
      });

      await sweep.expireDeletedCouriers();

      expect(await prisma.courier.findUnique({ where: { id: expired.id } })).toBeNull();
      expect(
        await prisma.courier.findUnique({ where: { id: insideWindow.id } }),
      ).not.toBeNull();

      // The burn does not take the delivery history with it: orders.courier_id is
      // ON DELETE SET NULL, so the order the customer cares about survives with
      // the courier unlinked.
      const order = await prisma.order.findUniqueOrThrow({ where: { id: orderId } });
      expect(order.courierId).toBeNull();
      expect(order.status).toBe(OrderStatus.COMPLETED);
    });

    it('leaves a blocked courier alone — no deletedAt means nothing to expire', async () => {
      const blocked = await createCourierDeletedDaysAgo('+79995550092', null);

      await sweep.expireDeletedCouriers();

      expect(await prisma.courier.findUnique({ where: { id: blocked.id } })).not.toBeNull();
    });
  });

  /**
   * The staff surface of the same window: the panel lists what the courier
   * deleted and hands a row back for the courier who cannot do it himself.
   *
   * Seeded with its own rows and its own owner rather than reusing the state
   * the blocks above leave behind — jest runs these in order, and a test that
   * only passes because of the previous block is a test that fails when run
   * alone.
   */
  describe('staff couriers: deleted list and restore', () => {
    const ownerPhone = '+79990000033';
    let ownerToken: string;

    const seedCourier = async (phone: string | null, deletedDaysAgo: number | null) =>
      prisma.courier.create({
        data: {
          name: `Staff ${phone ?? 'legacy'}`,
          phone,
          pinHash: await bcrypt.hash('1234', 4),
          brandId: fx.brandId,
          branchId: fx.branchId,
          tenantId: fx.tenantId,
          isActive: deletedDaysAgo === null,
          deletedAt:
            deletedDaysAgo === null
              ? null
              : new Date(Date.now() - deletedDaysAgo * 24 * 60 * 60 * 1000),
        },
      });

    const staffList = (query: Record<string, string>) =>
      http()
        .get('/staff/couriers')
        .query({ branchId: fx.branchId, ...query })
        .set('Authorization', `Bearer ${ownerToken}`);

    const staffRestore = (id: string) =>
      http()
        .post(`/staff/couriers/${id}/restore`)
        .set('Authorization', `Bearer ${ownerToken}`);

    const readCourierById = (id: string) =>
      prisma.courier.findUniqueOrThrow({ where: { id } });

    beforeAll(async () => {
      await prisma.staff.create({
        data: {
          name: 'Courier E2E Owner',
          phone: ownerPhone,
          pinHash: await bcrypt.hash('1234', 4),
          role: 'OWNER',
          brandId: fx.brandId,
          tenantId: fx.tenantId,
        },
      });
      const login = await http()
        .post('/staff/auth/pin')
        .send({ phone: ownerPhone, pin: '1234' })
        .expect(200);
      ownerToken = login.body.token;
    });

    afterAll(async () => {
      // `staff.brand_id` is fk_staff_brands (Restrict), so a leftover owner row
      // breaks the next suite's brand delete — the same debt menu.e2e-spec
      // documents at its own afterAll.
      await prisma.staff.deleteMany({ where: { phone: ownerPhone } });
    });

    it('lists live couriers by default and the deleted ones on request', async () => {
      const live = await seedCourier('+79995550101', null);
      const deleted = await seedCourier('+79995550102', 1);

      const liveRows = (await staffList({}).expect(200)).body;
      const deletedRows = (await staffList({ includeDeleted: 'true' }).expect(200)).body;

      expect(liveRows.map((c: any) => c.id)).toContain(live.id);
      expect(liveRows.map((c: any) => c.id)).not.toContain(deleted.id);
      expect(deletedRows.map((c: any) => c.id)).toContain(deleted.id);
      expect(deletedRows.map((c: any) => c.id)).not.toContain(live.id);

      // The panel dates the burn from deletedAt, so it has to be in the
      // payload — and a live row has to answer null for it, not omit the key.
      const deletedRow = deletedRows.find((c: any) => c.id === deleted.id);
      expect(typeof deletedRow.deletedAt).toBe('string');
      const liveRow = liveRows.find((c: any) => c.id === live.id);
      expect(liveRow.deletedAt).toBeNull();
    });

    it('hands back a deleted account with its number and PIN intact', async () => {
      const row = await seedCourier('+79995550110', 2);

      const res = await staffRestore(row.id).expect(200);
      expect(res.body).toMatchObject({
        id: row.id,
        phone: '+79995550110',
        isActive: true,
        deletedAt: null,
      });

      const courier = await readCourierById(row.id);
      expect(courier.deletedAt).toBeNull();
      expect(courier.isActive).toBe(true);
      expect(courier.phone).toBe('+79995550110');

      // Restored means usable: the PIN the courier already knows logs in again.
      await http()
        .post('/couriers/auth/pin')
        .send({ phone: '+79995550110', pin: '1234' })
        .expect(200);
    });

    it('404 on a courier that is not deleted', async () => {
      const live = await seedCourier('+79995550111', null);

      await staffRestore(live.id).expect(404);

      expect((await readCourierById(live.id)).isActive).toBe(true);
    });

    it('404 on a pre-window row whose number the old deletion erased', async () => {
      // Rows the old deletion touched still carry a fresh deletedAt but no
      // number and a randomized PIN. Reviving one is an account nobody can log
      // into, so the write refuses it rather than reporting a success.
      const legacy = await seedCourier(null, 1);

      await staffRestore(legacy.id).expect(404);

      const courier = await readCourierById(legacy.id);
      expect(courier.deletedAt).toBeInstanceOf(Date);
      expect(courier.isActive).toBe(false);
    });

    it('404 once the window has closed', async () => {
      const expired = await seedCourier(
        '+79995550112',
        COURIER_RESTORE_WINDOW_DAYS + 1,
      );

      await staffRestore(expired.id).expect(404);

      expect((await readCourierById(expired.id)).isActive).toBe(false);
    });

    it('404 on an id that does not exist', async () => {
      await staffRestore(randomUUID()).expect(404);
    });

    it('409 COURIER_PHONE_EXISTS when the number has been re-issued', async () => {
      // The partial index lets a live courier hold the number a deleted row
      // still has — the delete block above creates exactly that pair. Un-
      // deleting the old row would then leave two live rows on one number,
      // which is the state the login lookup cannot survive.
      const deleted = await seedCourier('+79995550120', 1);
      await seedCourier('+79995550120', null);

      const res = await staffRestore(deleted.id).expect(409);
      expect(res.body.code).toBe('COURIER_PHONE_EXISTS');
      expect((await readCourierById(deleted.id)).deletedAt).toBeInstanceOf(Date);
    });
  });
});
