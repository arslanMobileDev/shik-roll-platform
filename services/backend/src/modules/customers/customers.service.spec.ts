import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import {
  DELETION_TOKEN_TYPE,
  DeletionReason,
  PHONE_RELEASE_WINDOW_DAYS,
  RESTORE_TOKEN_TYPE,
} from './customers.config';
import { CustomersService } from './customers.service';

const CUSTOMER_ID = '10101010-1010-1010-1010-101010101010';
const OTHER_CUSTOMER_ID = '99999999-9999-9999-9999-999999999999';
const PHONE = '+79991234567';
const SECRET = 'customers-test-secret';

describe('CustomersService', () => {
  let service: CustomersService;
  let jwt: JwtService;
  let loyalty: { expireAllWithinTransaction: jest.Mock };
  let tx: {
    customer: { findUnique: jest.Mock; update: jest.Mock };
    order: { count: jest.Mock };
  };
  let prisma: {
    customer: { findUnique: jest.Mock; findFirst: jest.Mock };
    bonusAccount: { findUnique: jest.Mock };
    order: { count: jest.Mock };
    $transaction: jest.Mock;
  };

  beforeEach(async () => {
    tx = {
      customer: { findUnique: jest.fn(), update: jest.fn().mockResolvedValue({}) },
      order: { count: jest.fn().mockResolvedValue(0) },
    };
    prisma = {
      customer: { findUnique: jest.fn(), findFirst: jest.fn() },
      bonusAccount: { findUnique: jest.fn() },
      order: { count: jest.fn().mockResolvedValue(0) },
      $transaction: jest.fn((arg: unknown) =>
        (arg as (client: unknown) => unknown)(tx),
      ),
    };
    loyalty = {
      expireAllWithinTransaction: jest.fn().mockResolvedValue(0),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CustomersService,
        { provide: PrismaService, useValue: prisma },
        { provide: LoyaltyService, useValue: loyalty },
        { provide: JwtService, useValue: new JwtService({ secret: SECRET }) },
      ],
    }).compile();

    service = module.get(CustomersService);
    jwt = module.get(JwtService);
  });

  describe('requestDeletion', () => {
    it('reports the balance that will burn and mints a confirmation token', async () => {
      prisma.customer.findUnique.mockResolvedValue({ deletedAt: null });
      prisma.bonusAccount.findUnique.mockResolvedValue({ balance: 120 });

      const result = await service.requestDeletion(CUSTOMER_ID);

      expect(result).toMatchObject({
        bonusBalance: 120,
        canDelete: true,
        expiresInSeconds: 300,
      });
      expect(result.blockedReason).toBeUndefined();
      await expect(
        jwt.verifyAsync(result.deletionToken),
      ).resolves.toMatchObject({ sub: CUSTOMER_ID, type: DELETION_TOKEN_TYPE });
    });

    it('reports canDelete=false while an order is still in progress', async () => {
      prisma.customer.findUnique.mockResolvedValue({ deletedAt: null });
      prisma.bonusAccount.findUnique.mockResolvedValue({ balance: 0 });
      prisma.order.count.mockResolvedValue(2);

      await expect(service.requestDeletion(CUSTOMER_ID)).resolves.toMatchObject({
        canDelete: false,
        blockedReason: 'ACTIVE_ORDERS_EXIST',
      });
    });

    it('counts only the in-progress statuses — an unpaid checkout does not block', async () => {
      prisma.customer.findUnique.mockResolvedValue({ deletedAt: null });
      prisma.bonusAccount.findUnique.mockResolvedValue(null);

      await service.requestDeletion(CUSTOMER_ID);

      expect(prisma.order.count).toHaveBeenCalledWith({
        where: {
          customerId: CUSTOMER_ID,
          deletedAt: null,
          status: { in: ['NEW', 'CONFIRMED', 'COOKING', 'READY', 'ON_WAY'] },
        },
      });
    });

    it('treats a missing bonus account as a zero balance', async () => {
      prisma.customer.findUnique.mockResolvedValue({ deletedAt: null });
      prisma.bonusAccount.findUnique.mockResolvedValue(null);

      await expect(service.requestDeletion(CUSTOMER_ID)).resolves.toMatchObject({
        bonusBalance: 0,
      });
    });

    it('refuses a second deletion request on an already deleted account', async () => {
      prisma.customer.findUnique.mockResolvedValue({ deletedAt: new Date() });

      await expect(service.requestDeletion(CUSTOMER_ID)).rejects.toMatchObject({
        response: { code: 'ACCOUNT_ALREADY_DELETED' },
      });
    });
  });

  describe('confirmDeletion', () => {
    async function deletionToken(sub: string = CUSTOMER_ID): Promise<string> {
      return jwt.signAsync(
        { sub, type: DELETION_TOKEN_TYPE },
        { expiresIn: 300 },
      );
    }

    beforeEach(() => {
      tx.customer.findUnique.mockResolvedValue({ phone: PHONE, deletedAt: null });
    });

    it('burns the bonuses, anonymizes the row and parks the phone in one transaction', async () => {
      loyalty.expireAllWithinTransaction.mockResolvedValue(120);

      const result = await service.confirmDeletion(CUSTOMER_ID, {
        deletionToken: await deletionToken(),
      });

      expect(result).toEqual({ deleted: true, expiredBonusPoints: 120 });
      expect(loyalty.expireAllWithinTransaction).toHaveBeenCalledWith(tx, {
        customerId: CUSTOMER_ID,
        deletionId: expect.any(String),
      });
      expect(tx.customer.update).toHaveBeenCalledWith({
        where: { id: CUSTOMER_ID },
        data: {
          deletedAt: expect.any(Date),
          // Server-side constant: nothing from the request body lands here.
          deletedReason: DeletionReason.USER_REQUEST,
          phonePendingRelease: PHONE,
          phone: null,
          name: null,
          email: null,
        },
      });
    });

    it('rejects a token issued for another account', async () => {
      await expect(
        service.confirmDeletion(CUSTOMER_ID, {
          deletionToken: await deletionToken(OTHER_CUSTOMER_ID),
        }),
      ).rejects.toMatchObject({ response: { code: 'DELETION_TOKEN_MISMATCH' } });

      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('rejects an access token presented as a deletion token', async () => {
      const access = await jwt.signAsync({ sub: CUSTOMER_ID, type: 'access' });

      await expect(
        service.confirmDeletion(CUSTOMER_ID, { deletionToken: access }),
      ).rejects.toMatchObject({ response: { code: 'ACCOUNT_TOKEN_INVALID' } });
    });

    it('refuses deletion while an order is still in progress', async () => {
      tx.order.count.mockResolvedValue(1);

      await expect(
        service.confirmDeletion(CUSTOMER_ID, {
          deletionToken: await deletionToken(),
        }),
      ).rejects.toMatchObject({ response: { code: 'ACTIVE_ORDERS_EXIST' } });

      expect(loyalty.expireAllWithinTransaction).not.toHaveBeenCalled();
      expect(tx.customer.update).not.toHaveBeenCalled();
    });

    it('refuses a repeat deletion of the same account', async () => {
      tx.customer.findUnique.mockResolvedValue({
        phone: null,
        deletedAt: new Date('2026-10-01T00:00:00Z'),
      });

      await expect(
        service.confirmDeletion(CUSTOMER_ID, {
          deletionToken: await deletionToken(),
        }),
      ).rejects.toMatchObject({ response: { code: 'ACCOUNT_ALREADY_DELETED' } });

      expect(loyalty.expireAllWithinTransaction).not.toHaveBeenCalled();
    });
  });

  describe('findFrozenByPhone', () => {
    it('looks up the newest deletion inside the freeze window only', async () => {
      const deletedAt = new Date('2026-10-01T00:00:00Z');
      prisma.customer.findFirst.mockResolvedValue({ id: CUSTOMER_ID, deletedAt });

      await expect(service.findFrozenByPhone(PHONE)).resolves.toEqual({
        id: CUSTOMER_ID,
        deletedAt,
      });

      const where = prisma.customer.findFirst.mock.calls[0][0].where;
      expect(where.phonePendingRelease).toBe(PHONE);
      expect(where.deletedAt.gt).toBeInstanceOf(Date);
      expect(prisma.customer.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy: { deletedAt: 'desc' } }),
      );
    });

    it('cuts the window off exactly PHONE_RELEASE_WINDOW_DAYS back', async () => {
      prisma.customer.findFirst.mockResolvedValue(null);
      const before = Date.now();

      await service.findFrozenByPhone(PHONE);

      const cutoff: Date = prisma.customer.findFirst.mock.calls[0][0].where
        .deletedAt.gt;
      const expected =
        PHONE_RELEASE_WINDOW_DAYS * 24 * 60 * 60 * 1000;
      expect(cutoff.getTime()).toBeGreaterThanOrEqual(before - expected);
      expect(cutoff.getTime()).toBeLessThanOrEqual(Date.now() - expected);
    });

    it('ignores a row whose deletedAt came back null', async () => {
      prisma.customer.findFirst.mockResolvedValue({
        id: CUSTOMER_ID,
        deletedAt: null,
      });

      await expect(service.findFrozenByPhone(PHONE)).resolves.toBeNull();
    });
  });

  describe('unfreeze', () => {
    it('hands the parked phone back and lifts the tombstone', async () => {
      tx.customer.findUnique.mockResolvedValue({
        phonePendingRelease: PHONE,
        deletedAt: new Date('2026-10-01T00:00:00Z'),
      });
      tx.customer.update.mockResolvedValue({ id: CUSTOMER_ID, phone: PHONE });

      await expect(service.unfreeze(CUSTOMER_ID)).resolves.toMatchObject({
        id: CUSTOMER_ID,
        phone: PHONE,
      });

      expect(tx.customer.update).toHaveBeenCalledWith({
        where: { id: CUSTOMER_ID },
        data: {
          phone: PHONE,
          phonePendingRelease: null,
          deletedAt: null,
          deletedReason: null,
        },
      });
    });

    it('refuses to restore a live account', async () => {
      tx.customer.findUnique.mockResolvedValue({
        phonePendingRelease: null,
        deletedAt: null,
      });

      await expect(service.unfreeze(CUSTOMER_ID)).rejects.toMatchObject({
        response: { code: 'ACCOUNT_NOT_DELETED' },
      });
    });

    it('refuses to restore once the release job erased the parked number', async () => {
      tx.customer.findUnique.mockResolvedValue({
        phonePendingRelease: null,
        deletedAt: new Date('2026-01-01T00:00:00Z'),
      });

      await expect(service.unfreeze(CUSTOMER_ID)).rejects.toMatchObject({
        response: { code: 'RESTORE_WINDOW_EXPIRED' },
      });
    });
  });

  describe('verifyFlowToken', () => {
    it('rejects a restore token presented as a deletion token', async () => {
      const token = await jwt.signAsync({
        sub: CUSTOMER_ID,
        type: RESTORE_TOKEN_TYPE,
      });

      await expect(
        service.verifyFlowToken(token, DELETION_TOKEN_TYPE),
      ).rejects.toMatchObject({ response: { code: 'ACCOUNT_TOKEN_INVALID' } });
    });

    it('rejects a token with no subject', async () => {
      const token = jwt.sign({ type: RESTORE_TOKEN_TYPE });

      await expect(
        service.verifyFlowToken(token, RESTORE_TOKEN_TYPE),
      ).rejects.toMatchObject({ response: { code: 'ACCOUNT_TOKEN_INVALID' } });
    });
  });
});
