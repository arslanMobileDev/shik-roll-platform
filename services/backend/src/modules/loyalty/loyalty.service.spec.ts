import { ConflictException, UnprocessableEntityException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import {
  BonusTransactionType,
  Prisma,
  PromotionCampaignStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerKeys, LoyaltyService } from './loyalty.service';

const D = (value: string | number) => new Prisma.Decimal(value);

const CUSTOMER_ID = '10101010-1010-1010-1010-101010101010';
const ACCOUNT_ID = '20202020-2020-2020-2020-202020202020';
const ORDER_ID = '55555555-5555-5555-5555-555555555555';
const BRAND_ID = '11111111-1111-1111-1111-111111111111';

function makeAccount(balance = 500, cashbackRate = '5.00') {
  return {
    id: ACCOUNT_ID,
    customerId: CUSTOMER_ID,
    balance,
    cashbackRate: D(cashbackRate),
    createdAt: new Date('2026-09-01T10:00:00Z'),
    updatedAt: new Date('2026-09-01T10:00:00Z'),
  };
}

function makeTransaction(overrides: Record<string, unknown> = {}) {
  return {
    id: '30303030-3030-3030-3030-303030303030',
    accountId: ACCOUNT_ID,
    orderId: ORDER_ID,
    type: BonusTransactionType.SPEND,
    points: -200,
    balanceAfter: 300,
    idempotencyKey: LedgerKeys.spend(ORDER_ID),
    expiresAt: null,
    createdAt: new Date('2026-09-02T12:00:00Z'),
    ...overrides,
  };
}

describe('LoyaltyService', () => {
  let service: LoyaltyService;
  let prisma: {
    bonusAccount: { upsert: jest.Mock; findUnique: jest.Mock };
    bonusTransaction: { findMany: jest.Mock; count: jest.Mock; findUnique: jest.Mock };
    promotionCampaign: { findMany: jest.Mock };
    order: { findFirst: jest.Mock };
    $transaction: jest.Mock;
  };
  let tx: {
    bonusAccount: { findUnique: jest.Mock; create: jest.Mock; updateMany: jest.Mock };
    bonusTransaction: { findUnique: jest.Mock; create: jest.Mock };
  };

  beforeEach(async () => {
    tx = {
      bonusAccount: {
        findUnique: jest.fn(),
        create: jest.fn(),
        updateMany: jest.fn(),
      },
      bonusTransaction: { findUnique: jest.fn(), create: jest.fn() },
    };
    prisma = {
      bonusAccount: { upsert: jest.fn(), findUnique: jest.fn() },
      bonusTransaction: { findMany: jest.fn(), count: jest.fn(), findUnique: jest.fn() },
      promotionCampaign: { findMany: jest.fn() },
      order: { findFirst: jest.fn() },
      // Both Prisma transaction forms: batch arrays (reads) and interactive
      // callbacks (ledger mutations) share one mock.
      $transaction: jest.fn((arg: unknown) =>
        Array.isArray(arg)
          ? Promise.all(arg)
          : (arg as (client: unknown) => unknown)(tx),
      ),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [LoyaltyService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(LoyaltyService);
  });

  describe('getBalance', () => {
    it('auto-provisions the account on first access and returns an empty ledger', async () => {
      prisma.bonusAccount.upsert.mockResolvedValue(makeAccount(0, '0.00'));
      prisma.bonusTransaction.findMany.mockResolvedValue([]);
      prisma.bonusTransaction.count.mockResolvedValue(0);

      const result = await service.getBalance(CUSTOMER_ID, 1, 20);

      expect(prisma.bonusAccount.upsert).toHaveBeenCalledWith({
        where: { customerId: CUSTOMER_ID },
        update: {},
        create: { customerId: CUSTOMER_ID },
      });
      expect(result.balance).toBe(0);
      expect(result.cashback_rate).toBe(0);
      expect(result.transactions).toEqual([]);
      expect(result.pagination).toEqual({ page: 1, page_size: 20, total: 0, total_pages: 0 });
    });

    it('returns the balance, rate and a mapped ledger page, newest first', async () => {
      prisma.bonusAccount.upsert.mockResolvedValue(makeAccount(300, '7.50'));
      prisma.bonusTransaction.findMany.mockResolvedValue([makeTransaction()]);
      prisma.bonusTransaction.count.mockResolvedValue(21);

      const result = await service.getBalance(CUSTOMER_ID, 2, 20);

      expect(prisma.bonusTransaction.findMany).toHaveBeenCalledWith({
        where: { accountId: ACCOUNT_ID },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: 20,
        take: 20,
      });
      expect(result.balance).toBe(300);
      expect(result.cashback_rate).toBe(7.5);
      expect(result.transactions[0]).toEqual({
        id: '30303030-3030-3030-3030-303030303030',
        type: 'SPEND',
        points: -200,
        balance_after: 300,
        order_id: ORDER_ID,
        created_at: '2026-09-02T12:00:00.000Z',
        expires_at: null,
      });
      expect(result.pagination).toEqual({ page: 2, page_size: 20, total: 21, total_pages: 2 });
    });
  });

  describe('getPromotionFeed', () => {
    it('returns only ACTIVE in-window campaigns of the brand, priority first', async () => {
      const startsAt = new Date(Date.now() - 60_000);
      const endsAt = new Date(Date.now() + 3_600_000);
      prisma.promotionCampaign.findMany.mockResolvedValue([
        {
          id: '40404040-4040-4040-4040-404040404040',
          brandId: BRAND_ID,
          title: '2 ролла по цене 1',
          description: null,
          bannerUrl: 'https://cdn.example/banner.png',
          actionUrl: null,
          status: PromotionCampaignStatus.ACTIVE,
          priority: 10,
          startsAt,
          endsAt,
          createdAt: startsAt,
          updatedAt: startsAt,
        },
      ]);

      const before = Date.now();
      const result = await service.getPromotionFeed(BRAND_ID);
      const after = Date.now();

      const where = prisma.promotionCampaign.findMany.mock.calls[0][0].where;
      expect(where.brandId).toBe(BRAND_ID);
      expect(where.status).toBe(PromotionCampaignStatus.ACTIVE);
      // The window filter is evaluated against "now" inside the service call.
      expect(where.startsAt.lte.getTime()).toBeGreaterThanOrEqual(before);
      expect(where.startsAt.lte.getTime()).toBeLessThanOrEqual(after);
      expect(where.endsAt.gt.getTime()).toBeGreaterThanOrEqual(before);
      expect(where.endsAt.gt.getTime()).toBeLessThanOrEqual(after);
      expect(prisma.promotionCampaign.findMany.mock.calls[0][0].orderBy).toEqual([
        { priority: 'desc' },
        { startsAt: 'desc' },
      ]);
      expect(result.items).toEqual([
        {
          id: '40404040-4040-4040-4040-404040404040',
          title: '2 ролла по цене 1',
          description: null,
          banner_url: 'https://cdn.example/banner.png',
          action_url: null,
          starts_at: startsAt.toISOString(),
          ends_at: endsAt.toISOString(),
        },
      ]);
    });
  });

  describe('assertSpendAllowed — checkout guards (ADR-1614)', () => {
    it('rejects points above the 30% limit with 422 BONUS_LIMIT_EXCEEDED even when the balance covers them', async () => {
      prisma.bonusAccount.findUnique.mockResolvedValue(makeAccount(10_000));

      await expect(
        service.assertSpendAllowed(CUSTOMER_ID, 271, D('900.00')),
      ).rejects.toMatchObject({ response: { code: 'BONUS_LIMIT_EXCEEDED' } });
      await expect(
        service.assertSpendAllowed(CUSTOMER_ID, 271, D('900.00')),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);
    });

    it('accepts exactly the 30% limit', async () => {
      prisma.bonusAccount.findUnique.mockResolvedValue(makeAccount(270));
      await expect(
        service.assertSpendAllowed(CUSTOMER_ID, 270, D('900.00')),
      ).resolves.toBeUndefined();
    });

    it('rejects with 409 INSUFFICIENT_BONUS_BALANCE when the balance is short', async () => {
      prisma.bonusAccount.findUnique.mockResolvedValue(makeAccount(100));

      await expect(
        service.assertSpendAllowed(CUSTOMER_ID, 200, D('900.00')),
      ).rejects.toMatchObject({ response: { code: 'INSUFFICIENT_BONUS_BALANCE' } });
      await expect(
        service.assertSpendAllowed(CUSTOMER_ID, 200, D('900.00')),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('treats a missing account as a zero balance', async () => {
      prisma.bonusAccount.findUnique.mockResolvedValue(null);

      await expect(
        service.assertSpendAllowed(CUSTOMER_ID, 1, D('900.00')),
      ).rejects.toMatchObject({ response: { code: 'INSUFFICIENT_BONUS_BALANCE' } });
    });
  });

  describe('spendWithinTransaction — atomic checkout spend', () => {
    it('decrements the balance and appends a negative SPEND ledger entry', async () => {
      tx.bonusTransaction.findUnique.mockResolvedValue(null);
      tx.bonusAccount.findUnique.mockResolvedValue(makeAccount(500));
      tx.bonusAccount.updateMany.mockResolvedValue({ count: 1 });
      tx.bonusTransaction.create.mockResolvedValue({});

      await service.spendWithinTransaction(tx as never, {
        customerId: CUSTOMER_ID,
        orderId: ORDER_ID,
        points: 200,
      });

      expect(tx.bonusAccount.updateMany).toHaveBeenCalledWith({
        where: { id: ACCOUNT_ID, balance: 500 },
        data: { balance: 300 },
      });
      expect(tx.bonusTransaction.create).toHaveBeenCalledWith({
        data: {
          accountId: ACCOUNT_ID,
          orderId: ORDER_ID,
          type: BonusTransactionType.SPEND,
          points: -200,
          balanceAfter: 300,
          idempotencyKey: LedgerKeys.spend(ORDER_ID),
        },
      });
    });

    it('is a no-op when the spend:{orderId} entry already exists (idempotent)', async () => {
      tx.bonusTransaction.findUnique.mockResolvedValue({ id: 'existing' });

      await service.spendWithinTransaction(tx as never, {
        customerId: CUSTOMER_ID,
        orderId: ORDER_ID,
        points: 200,
      });

      expect(tx.bonusAccount.updateMany).not.toHaveBeenCalled();
      expect(tx.bonusTransaction.create).not.toHaveBeenCalled();
    });

    it('rejects with 409 INSUFFICIENT_BONUS_BALANCE without writing anything when the balance raced below the spend', async () => {
      tx.bonusTransaction.findUnique.mockResolvedValue(null);
      tx.bonusAccount.findUnique.mockResolvedValue(makeAccount(100));

      await expect(
        service.spendWithinTransaction(tx as never, {
          customerId: CUSTOMER_ID,
          orderId: ORDER_ID,
          points: 200,
        }),
      ).rejects.toMatchObject({ response: { code: 'INSUFFICIENT_BONUS_BALANCE' } });

      expect(tx.bonusAccount.updateMany).not.toHaveBeenCalled();
      expect(tx.bonusTransaction.create).not.toHaveBeenCalled();
    });

    it('rejects with 409 when the customer has no bonus account at all', async () => {
      tx.bonusTransaction.findUnique.mockResolvedValue(null);
      tx.bonusAccount.findUnique.mockResolvedValue(null);

      await expect(
        service.spendWithinTransaction(tx as never, {
          customerId: CUSTOMER_ID,
          orderId: ORDER_ID,
          points: 200,
        }),
      ).rejects.toMatchObject({ response: { code: 'INSUFFICIENT_BONUS_BALANCE' } });
      expect(tx.bonusAccount.create).not.toHaveBeenCalled();
    });

    it('retries the compare-and-set when the balance moved concurrently', async () => {
      tx.bonusTransaction.findUnique.mockResolvedValue(null);
      tx.bonusAccount.findUnique
        .mockResolvedValueOnce(makeAccount(500))
        .mockResolvedValueOnce(makeAccount(520));
      tx.bonusAccount.updateMany
        .mockResolvedValueOnce({ count: 0 }) // lost the race — re-read
        .mockResolvedValueOnce({ count: 1 });
      tx.bonusTransaction.create.mockResolvedValue({});

      await service.spendWithinTransaction(tx as never, {
        customerId: CUSTOMER_ID,
        orderId: ORDER_ID,
        points: 200,
      });

      expect(tx.bonusAccount.updateMany).toHaveBeenCalledTimes(2);
      // balance_after reflects the re-read balance: 520 - 200 = 320
      expect(tx.bonusTransaction.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ balanceAfter: 320 }),
      });
    });
  });

  describe('earnCashback — accrual on COMPLETED', () => {
    it('accrues floor(payable * rate / 100) as an EARN entry', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: CUSTOMER_ID, totalAmount: D('999.00') });
      prisma.bonusAccount.findUnique.mockResolvedValue(makeAccount(300, '5.00'));
      tx.bonusTransaction.findUnique.mockResolvedValue(null);
      tx.bonusAccount.findUnique.mockResolvedValue(makeAccount(300, '5.00'));
      tx.bonusAccount.updateMany.mockResolvedValue({ count: 1 });
      tx.bonusTransaction.create.mockResolvedValue({});

      await service.earnCashback(ORDER_ID);

      // 999 * 5% = 49.95 -> 49 points
      expect(tx.bonusTransaction.create).toHaveBeenCalledWith({
        data: {
          accountId: ACCOUNT_ID,
          orderId: ORDER_ID,
          type: BonusTransactionType.EARN,
          points: 49,
          balanceAfter: 349,
          idempotencyKey: LedgerKeys.earn(ORDER_ID),
        },
      });
    });

    it('is a no-op for a guest (customerless) order', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: null, totalAmount: D('999.00') });

      await service.earnCashback(ORDER_ID);

      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('accrues nothing at a zero cashback rate (ledger rows are never zero)', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: CUSTOMER_ID, totalAmount: D('999.00') });
      prisma.bonusAccount.findUnique.mockResolvedValue(makeAccount(300, '0.00'));

      await service.earnCashback(ORDER_ID);

      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('never accrues twice: a repeated COMPLETED leaves the balance untouched', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: CUSTOMER_ID, totalAmount: D('999.00') });
      prisma.bonusAccount.findUnique.mockResolvedValue(makeAccount(300, '5.00'));
      // The earn:{orderId} entry already exists — a repeated transition.
      tx.bonusTransaction.findUnique.mockResolvedValue({ id: 'existing' });

      await service.earnCashback(ORDER_ID);

      expect(tx.bonusAccount.updateMany).not.toHaveBeenCalled();
      expect(tx.bonusTransaction.create).not.toHaveBeenCalled();
    });

    it('tolerates a concurrent application of the same ledger key (unique violation)', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: CUSTOMER_ID, totalAmount: D('999.00') });
      prisma.bonusAccount.findUnique.mockResolvedValue(makeAccount(300, '5.00'));
      tx.bonusTransaction.findUnique.mockResolvedValue(null);
      tx.bonusAccount.findUnique.mockResolvedValue(makeAccount(300, '5.00'));
      tx.bonusAccount.updateMany.mockResolvedValue({ count: 1 });
      tx.bonusTransaction.create.mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
          code: 'P2002',
          clientVersion: '6.19.3',
        }),
      );

      await expect(service.earnCashback(ORDER_ID)).resolves.toBeUndefined();
    });
  });

  describe('refundOnCancel — compensation for a cancelled order', () => {
    it('restores the spent points as a positive REFUND entry', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: CUSTOMER_ID });
      prisma.bonusTransaction.findUnique.mockResolvedValue(makeTransaction());
      tx.bonusTransaction.findUnique.mockResolvedValue(null);
      tx.bonusAccount.findUnique.mockResolvedValue(makeAccount(300));
      tx.bonusAccount.updateMany.mockResolvedValue({ count: 1 });
      tx.bonusTransaction.create.mockResolvedValue({});

      await service.refundOnCancel(ORDER_ID);

      expect(tx.bonusAccount.updateMany).toHaveBeenCalledWith({
        where: { id: ACCOUNT_ID, balance: 300 },
        data: { balance: 500 },
      });
      expect(tx.bonusTransaction.create).toHaveBeenCalledWith({
        data: {
          accountId: ACCOUNT_ID,
          orderId: ORDER_ID,
          type: BonusTransactionType.REFUND,
          points: 200,
          balanceAfter: 500,
          idempotencyKey: LedgerKeys.refund(ORDER_ID),
        },
      });
    });

    it('is a no-op when the order never spent bonuses', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: CUSTOMER_ID });
      prisma.bonusTransaction.findUnique.mockResolvedValue(null);

      await service.refundOnCancel(ORDER_ID);

      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('is a no-op for a guest order', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: null });

      await service.refundOnCancel(ORDER_ID);

      expect(prisma.bonusTransaction.findUnique).not.toHaveBeenCalled();
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('never refunds twice for the same order', async () => {
      prisma.order.findFirst.mockResolvedValue({ customerId: CUSTOMER_ID });
      prisma.bonusTransaction.findUnique.mockResolvedValue(makeTransaction());
      // The refund:{orderId} entry already exists.
      tx.bonusTransaction.findUnique.mockResolvedValue({ id: 'existing' });

      await service.refundOnCancel(ORDER_ID);

      expect(tx.bonusAccount.updateMany).not.toHaveBeenCalled();
      expect(tx.bonusTransaction.create).not.toHaveBeenCalled();
    });
  });
});
