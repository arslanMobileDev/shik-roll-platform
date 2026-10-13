import { execSync } from 'node:child_process';
import * as path from 'node:path';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { OrderStatus, OrderType, PrismaClient } from '@prisma/client';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { DEV_OTP_CODE, OTP_TTL_SECONDS } from '../src/modules/auth/auth.config';
import {
  DeletionReason,
  PHONE_RELEASE_WINDOW_DAYS,
} from '../src/modules/customers/customers.config';

/**
 * E2E coverage of customer self-service account deletion (Apple requirement):
 *   - POST /customers/me/deletion-request — preview (burned balance, blocker)
 *     and the one-shot confirmation token;
 *   - POST /customers/me/deletion-confirm — bonus burn, anonymization, phone
 *     freeze, active-order guard, repeat-deletion guard;
 *   - revoked access: a deleted customer's still-valid token answers 401;
 *   - POST /auth/restore — tombstone lifted, phone back, history returned;
 *   - the frozen-phone branch of POST /auth/otp/verify — an offer instead of a
 *     session, and no account provisioned when the offer is not taken;
 *   - the freeze window closing: no offer, registration proceeds normally.
 *
 * Runs against DATABASE_URL_TEST (same convention as auth.e2e-spec.ts).
 * Orders and bonus accounts are seeded straight through Prisma: the flows
 * under test are the deletion and restore ones, not checkout.
 */

const TEST_DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://postgres:postgres@shik_menu_test?schema=public';

process.env.DATABASE_URL = TEST_DATABASE_URL;
delete process.env.SMS_PROVIDER;
delete process.env.DEV_OTP;
delete process.env.REDIS_URL;
delete process.env.REDIS_HOST;

const prisma = new PrismaClient({ datasourceUrl: TEST_DATABASE_URL });

/**
 * Clears every table touched by this spec in FK-safe order.
 *
 * bonus_transactions/bonus_accounts come before customers on purpose:
 * fk_bonus_accounts_customers is ON DELETE RESTRICT, so the customer delete
 * fails as soon as this spec has created a bonus account.
 */
async function truncateAll(): Promise<void> {
  await prisma.payment.deleteMany();
  await prisma.orderStatusHistory.deleteMany();
  await prisma.orderItemModifier.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.bonusTransaction.deleteMany();
  await prisma.bonusAccount.deleteMany();
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
  await prisma.courier.deleteMany();
  await prisma.brandBranch.deleteMany();
  await prisma.orderSequence.deleteMany();
  await prisma.cookShift.deleteMany();
  await prisma.kitchenTerminal.deleteMany();
  await prisma.branch.deleteMany();
  await prisma.staff.deleteMany();
  await prisma.brand.deleteMany();
}

/** Unique +7 phone per call — the OTP resend cooldown is per phone. */
let phoneSeq = 0;
function nextPhone(): string {
  phoneSeq += 1;
  return `+7998${String(phoneSeq).padStart(7, '0')}`;
}

let app: INestApplication;
let http: ReturnType<typeof request>;

/** Signs a guest in through the real OTP flow and returns their session. */
async function signInGuest(
  phone: string,
): Promise<{ token: string; customerId: string }> {
  const sent = await http.post('/auth/otp/send').send({ phone }).expect(200);
  expect(sent.body.devCode).toBe(DEV_OTP_CODE);
  expect(sent.body.expiresInSeconds).toBe(OTP_TTL_SECONDS);
  const verified = await http
    .post('/auth/otp/verify')
    .send({ phone, code: DEV_OTP_CODE })
    .expect(200);
  return {
    token: verified.body.accessToken as string,
    customerId: verified.body.customer.id as string,
  };
}

/**
 * Requests a second OTP for a phone already used in the same test. The resend
 * cooldown is 1s in e2e (OTP_SEND_COOLDOWN_SECONDS in setup-e2e.ts), and the
 * limit itself stays active.
 */
async function resendOtp(phone: string): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 1_100));
  await http.post('/auth/otp/send').send({ phone }).expect(200);
}

let tenantId: string;
let brandId: string;
let branchId: string;
let orderSeq = 0;

/** One delivery order for the customer — the financial history that survives. */
async function seedOrder(
  customerId: string,
  status: OrderStatus = OrderStatus.COMPLETED,
): Promise<string> {
  orderSeq += 1;
  const order = await prisma.order.create({
    data: {
      tenantId,
      brandId,
      branchId,
      customerId,
      orderNumber: `E2E-${orderSeq}`,
      type: OrderType.DELIVERY,
      status,
      totalAmount: '1000.00',
      deliveryAddress: 'ул. Тестовая, 1',
    },
  });
  return order.id;
}

/** A bonus account with a real balance, so the burn has something to burn. */
async function seedBonusAccount(
  customerId: string,
  balance: number,
): Promise<string> {
  const account = await prisma.bonusAccount.create({
    data: { customerId, tenantId, balance },
  });
  return account.id;
}

describe('Customer account deletion (e2e)', () => {
  beforeAll(async () => {
    execSync('pnpm prisma migrate deploy', {
      cwd: path.resolve(__dirname, '..'),
      env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
      stdio: 'inherit',
    });
    await truncateAll();

    const tenant = await prisma.tenant.findUniqueOrThrow({
      where: { code: 'SHIK_ROLL' },
    });
    tenantId = tenant.id;
    const brand = await prisma.brand.create({
      data: { code: 'SHIK_ROLL', name: 'SHIK ROLL', tenantId },
    });
    brandId = brand.id;
    const branch = await prisma.branch.create({
      data: { code: 'A-01', name: 'Branch A1', tenantId },
    });
    branchId = branch.id;
    // ADR-1622 step 5: orders prove their (tenant, brand, branch) triple
    // against brand_branches, so the link has to exist first.
    await prisma.brandBranch.create({ data: { tenantId, brandId, branchId } });

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true }));
    await app.init();
    http = request(app.getHttpServer());
  }, 60_000);

  afterAll(async () => {
    await app?.close();
    await truncateAll();
    await prisma.$disconnect();
  });

  it('burns the bonuses, anonymizes the account and freezes the phone', async () => {
    const phone = nextPhone();
    const { token, customerId } = await signInGuest(phone);
    const orderId = await seedOrder(customerId);
    await seedBonusAccount(customerId, 500);

    const preview = await http
      .post('/customers/me/deletion-request')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(preview.body).toMatchObject({
      bonusBalance: 500,
      canDelete: true,
      expiresInSeconds: 300,
    });
    expect(preview.body.blockedReason).toBeUndefined();

    const confirmed = await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: preview.body.deletionToken })
      .expect(200);
    expect(confirmed.body).toEqual({ deleted: true, expiredBonusPoints: 500 });

    const row = await prisma.customer.findUniqueOrThrow({
      where: { id: customerId },
    });
    expect(row.phone).toBeNull();
    expect(row.name).toBeNull();
    expect(row.email).toBeNull();
    expect(row.deletedReason).toBe(DeletionReason.USER_REQUEST);
    expect(row.phonePendingRelease).toBe(phone);
    expect(row.deletedAt).toBeInstanceOf(Date);

    // The ledger records the burn, and the balance projection agrees with it.
    const account = await prisma.bonusAccount.findUniqueOrThrow({
      where: { customerId },
    });
    expect(account.balance).toBe(0);
    const entries = await prisma.bonusTransaction.findMany({
      where: { accountId: account.id },
    });
    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({ type: 'EXPIRE', points: -500, balanceAfter: 0 });
    expect(entries[0].idempotencyKey).toMatch(
      new RegExp(`^expire:delete:${customerId}:`),
    );

    // The freed number is re-registrable: the unique index no longer holds it.
    const reissued = await prisma.customer.findUnique({ where: { phone } });
    expect(reissued).toBeNull();

    // The order survives as a financial record, still pointing at the row.
    const order = await prisma.order.findUniqueOrThrow({ where: { id: orderId } });
    expect(order.customerId).toBe(customerId);
  });

  it('revokes the access token of a deleted customer', async () => {
    const phone = nextPhone();
    const { token } = await signInGuest(phone);
    await http
      .get('/orders/my')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const preview = await http
      .post('/customers/me/deletion-request')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: preview.body.deletionToken })
      .expect(200);

    // The JWT is still cryptographically valid for 30 days — the row check is
    // what ends the session.
    for (const path of ['/orders/my', '/auth/me', '/loyalty/balance']) {
      await http
        .get(path)
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
    }
  });

  it('blocks deletion while an order is in progress, but not on an unpaid checkout', async () => {
    const phone = nextPhone();
    const { token, customerId } = await signInGuest(phone);
    const activeOrderId = await seedOrder(customerId, OrderStatus.COOKING);
    const unpaidOrderId = await seedOrder(customerId, OrderStatus.PENDING_PAYMENT);

    const blocked = await http
      .post('/customers/me/deletion-request')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(blocked.body).toMatchObject({
      canDelete: false,
      blockedReason: 'ACTIVE_ORDERS_EXIST',
    });

    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: blocked.body.deletionToken })
      .expect(409)
      .expect((res) => expect(res.body.code).toBe('ACTIVE_ORDERS_EXIST'));

    // An abandoned unpaid checkout must not lock the account out of deletion.
    await prisma.order.update({
      where: { id: activeOrderId },
      data: { status: OrderStatus.CANCELLED },
    });
    expect(unpaidOrderId).toBeTruthy();

    const retry = await http
      .post('/customers/me/deletion-request')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(retry.body.canDelete).toBe(true);
    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: retry.body.deletionToken })
      .expect(200);
  });

  it('refuses a second deletion and a token issued for another account', async () => {
    const phone = nextPhone();
    const { token } = await signInGuest(phone);
    const preview = await http
      .post('/customers/me/deletion-request')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const other = await signInGuest(nextPhone());
    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${other.token}`)
      .send({ deletionToken: preview.body.deletionToken })
      .expect(403)
      .expect((res) => expect(res.body.code).toBe('DELETION_TOKEN_MISMATCH'));

    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: preview.body.deletionToken })
      .expect(200);

    // A repeat deletion is refused, not silently accepted.
    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: preview.body.deletionToken })
      .expect(401); // the account is gone, so the guard rejects the session first
  });

  it('offers a restore on sign-in, provisions nothing when it is not taken, and returns history on restore', async () => {
    const phone = nextPhone();
    const { token, customerId } = await signInGuest(phone);
    const orderId = await seedOrder(customerId);
    await seedBonusAccount(customerId, 300);

    const preview = await http
      .post('/customers/me/deletion-request')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: preview.body.deletionToken })
      .expect(200);

    // --- Sign-in offers the restore instead of a session.
    await resendOtp(phone);
    const offered = await http
      .post('/auth/otp/verify')
      .send({ phone, code: DEV_OTP_CODE })
      .expect(200);
    expect(offered.body).toMatchObject({
      status: 'RESTORE_AVAILABLE',
      expiresInSeconds: 300,
    });
    expect(offered.body.accessToken).toBeUndefined();

    // --- Declining creates nothing: the number stays frozen, one row only.
    expect(await prisma.customer.count({ where: { phonePendingRelease: phone } })).toBe(1);
    expect(await prisma.customer.count({ where: { phone } })).toBe(0);

    // The offer comes back on the next attempt.
    await resendOtp(phone);
    const offeredAgain = await http
      .post('/auth/otp/verify')
      .send({ phone, code: DEV_OTP_CODE })
      .expect(200);
    expect(offeredAgain.body.status).toBe('RESTORE_AVAILABLE');

    // --- Accepting: tombstone lifted, phone back, history returned.
    const restored = await http
      .post('/auth/restore')
      .send({ restoreToken: offeredAgain.body.restoreToken })
      .expect(200);
    expect(restored.body.customer.id).toBe(customerId);
    expect(restored.body.customer.phone).toBe(phone);

    const row = await prisma.customer.findUniqueOrThrow({ where: { id: customerId } });
    expect(row.deletedAt).toBeNull();
    expect(row.deletedReason).toBeNull();
    expect(row.phonePendingRelease).toBeNull();

    const history = await http
      .get('/orders/my')
      .set('Authorization', `Bearer ${restored.body.accessToken}`)
      .expect(200);
    expect(history.body.data.map((o: { id: string }) => o.id)).toContain(orderId);

    // The bonuses burned by the deletion stay burned.
    const balance = await http
      .get('/loyalty/balance')
      .set('Authorization', `Bearer ${restored.body.accessToken}`)
      .expect(200);
    expect(balance.body.balance).toBe(0);

    // A restore token is one-shot in effect: the account is live again.
    await http
      .post('/auth/restore')
      .send({ restoreToken: offeredAgain.body.restoreToken })
      .expect(409)
      .expect((res) => expect(res.body.code).toBe('ACCOUNT_NOT_DELETED'));
  });

  it('re-registers on the number once the freeze window has closed', async () => {
    const phone = nextPhone();
    const { token, customerId } = await signInGuest(phone);
    const preview = await http
      .post('/customers/me/deletion-request')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    await http
      .post('/customers/me/deletion-confirm')
      .set('Authorization', `Bearer ${token}`)
      .send({ deletionToken: preview.body.deletionToken })
      .expect(200);

    // Backdate the deletion past the window rather than waiting 30 days.
    const longAgo = new Date(
      Date.now() - (PHONE_RELEASE_WINDOW_DAYS + 1) * 24 * 60 * 60 * 1000,
    );
    await prisma.customer.update({
      where: { id: customerId },
      data: { deletedAt: longAgo },
    });

    await resendOtp(phone);
    const verified = await http
      .post('/auth/otp/verify')
      .send({ phone, code: DEV_OTP_CODE })
      .expect(200);

    // No offer — the number is free again and a fresh account is provisioned.
    expect(verified.body.accessToken).toBeDefined();
    expect(verified.body.status).toBeUndefined();
    expect(verified.body.customer.id).not.toBe(customerId);
    expect(verified.body.customer.phone).toBe(phone);
  });
});
