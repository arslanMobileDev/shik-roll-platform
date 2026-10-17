import { Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Customer } from '@prisma/client';
import { maskPhone } from '../../common/utils/mask-phone';
import {
  ACCESS_TOKEN_TTL_SECONDS,
  DEV_OTP_CODE,
  OTP_MAX_ATTEMPTS,
  OTP_SEND_COOLDOWN_SECONDS,
  OTP_TTL_SECONDS,
  REFRESH_TOKEN_TTL_SECONDS,
} from './auth.config';
import { AuthService } from './auth.service';
import { RESTORE_TOKEN_TYPE } from '../customers/customers.config';
import { AuthTokensResponse, RestoreOfferResponse } from './entities/auth.entities';
import { InMemoryOtpStore } from './otp-store.service';
import { SmsProvider } from './providers/sms/sms.provider';

const PHONE = '+79991234567';
const CUSTOMER_ID = '11111111-1111-1111-1111-111111111111';
const TENANT_ID = '22222222-2222-2222-2222-222222222222';

/**
 * verifyOtp answers with a union: a session, or the RESTORE_AVAILABLE offer
 * for a frozen phone. These tests exercise the session branch.
 */
function requireSession(
  result: AuthTokensResponse | RestoreOfferResponse,
): AuthTokensResponse {
  if (!('accessToken' in result)) {
    throw new Error(`expected a session, got ${result.status}`);
  }
  return result;
}

/** The mirror of requireSession: the frozen-phone branch. */
function requireRestoreOffer(
  result: AuthTokensResponse | RestoreOfferResponse,
): RestoreOfferResponse {
  if ('accessToken' in result) {
    throw new Error('expected a restore offer, got a session');
  }
  return result;
}

function makeCustomer(phone: string | null = PHONE): Customer {
  return {
    id: CUSTOMER_ID,
    tenantId: TENANT_ID,
    phone,
    name: null,
    email: null,
    role: 'CUSTOMER',
    createdAt: new Date('2026-09-04T10:00:00Z'),
    updatedAt: new Date('2026-09-04T10:00:00Z'),
    deletedAt: null,
    deletedReason: null,
    phonePendingRelease: null,
  };
}

describe('AuthService', () => {
  let service: AuthService;
  let otpStore: InMemoryOtpStore;
  let jwt: JwtService;
  let sms: { send: jest.Mock };
  let prisma: {
    customer: { upsert: jest.Mock; findUnique: jest.Mock };
    tenant: { findUnique: jest.Mock };
  };
  let customers: { findFrozenByPhone: jest.Mock; unfreeze: jest.Mock; verifyFlowToken: jest.Mock };
  let originalNodeEnv: string | undefined;

  beforeEach(() => {
    otpStore = new InMemoryOtpStore();
    jwt = new JwtService({ secret: 'unit-test-secret' });
    sms = { send: jest.fn().mockResolvedValue(undefined) };
    prisma = {
      customer: {
        upsert: jest.fn().mockResolvedValue(makeCustomer()),
        findUnique: jest.fn().mockResolvedValue(makeCustomer()),
      },
      // ADR-1622: the tenant is looked up by code, never by a hardcoded UUID.
      tenant: { findUnique: jest.fn().mockResolvedValue({ id: TENANT_ID }) },
    };
    // The deleted-account lookup: no frozen row unless a test stages one.
    customers = {
      findFrozenByPhone: jest.fn().mockResolvedValue(null),
      unfreeze: jest.fn().mockResolvedValue(makeCustomer()),
      verifyFlowToken: jest.fn().mockResolvedValue({ sub: CUSTOMER_ID }),
    };
    service = new AuthService(
      otpStore,
      sms as unknown as SmsProvider,
      jwt,
      prisma as never,
      customers as never,
    );
    originalNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'test';
    delete process.env.SMS_PROVIDER;
    delete process.env.DEV_OTP;
  });

  afterEach(() => {
    process.env.NODE_ENV = originalNodeEnv;
  });

  describe('sendOtp', () => {
    it('stores the fixed dev code 1111 with the configured TTL outside production', async () => {
      const setSpy = jest.spyOn(otpStore, 'set');
      const result = await service.sendOtp({ phone: PHONE });

      expect(result).toEqual({
        phone: PHONE,
        expiresInSeconds: OTP_TTL_SECONDS,
        devCode: DEV_OTP_CODE,
      });
      expect(setSpy).toHaveBeenCalledWith(PHONE, DEV_OTP_CODE, OTP_TTL_SECONDS);
      await expect(otpStore.get(PHONE)).resolves.toMatchObject({
        code: DEV_OTP_CODE,
        attempts: 0,
      });
    });

    it('OTP TTL defaults to 300 seconds (5 minutes)', () => {
      expect(OTP_TTL_SECONDS).toBe(300);
    });

    it('logs the dev-mode OTP against a masked phone, never the full number', async () => {
      const log = jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
      try {
        await service.sendOtp({ phone: PHONE });

        const logged = log.mock.calls.flat().join(' ');
        expect(logged).toContain(`OTP for ${maskPhone(PHONE)}`);
        expect(logged).not.toContain(PHONE);
      } finally {
        log.mockRestore();
      }
    });

    it('forces the fixed dev code in production when DEV_OTP=true', async () => {
      process.env.NODE_ENV = 'production';
      process.env.DEV_OTP = 'true';
      const result = await service.sendOtp({ phone: PHONE });

      expect(result.devCode).toBe(DEV_OTP_CODE);
      await expect(otpStore.get(PHONE)).resolves.toMatchObject({ code: DEV_OTP_CODE });
    });

    it('generates a random 4-digit code in production and never returns it', async () => {
      process.env.NODE_ENV = 'production';
      const result = await service.sendOtp({ phone: PHONE });

      expect(result.expiresInSeconds).toBe(OTP_TTL_SECONDS);
      expect(result.devCode).toBeUndefined();
      const entry = await otpStore.get(PHONE);
      expect(entry?.code).toMatch(/^\d{4}$/);
    });

    it('dispatches the OTP through the SMS provider in production', async () => {
      process.env.NODE_ENV = 'production';
      await service.sendOtp({ phone: PHONE });

      expect(sms.send).toHaveBeenCalledTimes(1);
      const [calledPhone, calledCode] = sms.send.mock.calls[0];
      expect(calledPhone).toBe(PHONE);
      expect(calledCode).toMatch(/^\d{4}$/);
    });

    it('does not call the SMS provider in dev mode', async () => {
      // NODE_ENV is 'test' in beforeEach — dev mode is active.
      await service.sendOtp({ phone: PHONE });
      expect(sms.send).not.toHaveBeenCalled();
    });

    it('propagates SMS provider failures so the client can retry', async () => {
      process.env.NODE_ENV = 'production';
      sms.send.mockRejectedValueOnce(new Error('gateway down'));

      await expect(service.sendOtp({ phone: PHONE })).rejects.toThrow('gateway down');
    });

    it('releases the resend slot when the SMS provider fails, so the retry is not 429', async () => {
      process.env.NODE_ENV = 'production';
      sms.send.mockRejectedValueOnce(new Error('gateway down'));

      await expect(service.sendOtp({ phone: PHONE })).rejects.toThrow('gateway down');
      await expect(service.sendOtp({ phone: PHONE })).resolves.toMatchObject({ phone: PHONE });
      expect(sms.send).toHaveBeenCalledTimes(2);
    });

    it('does not store a code when the SMS provider fails', async () => {
      process.env.NODE_ENV = 'production';
      sms.send.mockRejectedValueOnce(new Error('gateway down'));

      await expect(service.sendOtp({ phone: PHONE })).rejects.toThrow('gateway down');
      await expect(otpStore.get(PHONE)).resolves.toBeNull();
      // A failed send must not hand out a fresh 5-attempt budget: there is no
      // stored code to guess, so verify answers OTP_EXPIRED and counts nothing.
      await expect(service.verifyOtp({ phone: PHONE, code: '1111' })).rejects.toMatchObject({
        response: { code: 'OTP_EXPIRED' },
      });
    });

    it('keeps the gateway error when releasing the slot fails', async () => {
      process.env.NODE_ENV = 'production';
      sms.send.mockRejectedValueOnce(new Error('gateway down'));
      jest.spyOn(otpStore, 'releaseSendSlot').mockRejectedValueOnce(new Error('redis down'));

      await expect(service.sendOtp({ phone: PHONE })).rejects.toThrow('gateway down');
    });

    it('rate limits resend: second send within the cooldown window is rejected (429)', async () => {
      await service.sendOtp({ phone: PHONE });
      await expect(service.sendOtp({ phone: PHONE })).rejects.toMatchObject({
        status: 429,
        response: { code: 'OTP_SEND_RATE_LIMITED' },
      });
    });

    it('allows a resend after the cooldown window elapses', async () => {
      jest.useFakeTimers();
      try {
        await service.sendOtp({ phone: PHONE });
        jest.advanceTimersByTime((OTP_SEND_COOLDOWN_SECONDS + 1) * 1000);
        await expect(service.sendOtp({ phone: PHONE })).resolves.toMatchObject({
          phone: PHONE,
        });
      } finally {
        jest.useRealTimers();
      }
    });
  });

  describe('InMemoryOtpStore send slot', () => {
    it('releases only the slot owned by the given token', async () => {
      const store = new InMemoryOtpStore();
      jest.useFakeTimers();
      try {
        const stale = await store.acquireSendSlot(PHONE, 1);
        expect(stale).not.toBeNull();
        jest.advanceTimersByTime(2_000);

        const fresh = await store.acquireSendSlot(PHONE, 60);
        expect(fresh).not.toBeNull();
        expect(fresh).not.toBe(stale);

        // A slow, stale send must not free the slot a newer request owns.
        await store.releaseSendSlot(PHONE, stale!);
        await expect(store.acquireSendSlot(PHONE, 60)).resolves.toBeNull();

        await store.releaseSendSlot(PHONE, fresh!);
        await expect(store.acquireSendSlot(PHONE, 60)).resolves.not.toBeNull();
      } finally {
        jest.useRealTimers();
      }
    });
  });

  describe('verifyOtp', () => {
    it('rejects when no code was requested (401 OTP_EXPIRED)', async () => {
      await expect(service.verifyOtp({ phone: PHONE, code: '1111' })).rejects.toMatchObject({
        response: { code: 'OTP_EXPIRED' },
      });
      await expect(
        service.verifyOtp({ phone: PHONE, code: '1111' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects a wrong code (401 OTP_INVALID) and keeps the stored code', async () => {
      await service.sendOtp({ phone: PHONE });
      await expect(service.verifyOtp({ phone: PHONE, code: '9999' })).rejects.toMatchObject({
        response: { code: 'OTP_INVALID' },
      });
      // The stored code survives a failed attempt.
      await expect(otpStore.get(PHONE)).resolves.toMatchObject({
        code: DEV_OTP_CODE,
        attempts: 1,
      });
    });

    it('burns the code after OTP_MAX_ATTEMPTS wrong attempts (429 OTP_ATTEMPTS_EXCEEDED)', async () => {
      await service.sendOtp({ phone: PHONE });
      for (let attempt = 1; attempt < OTP_MAX_ATTEMPTS; attempt += 1) {
        await expect(
          service.verifyOtp({ phone: PHONE, code: '9999' }),
        ).rejects.toMatchObject({ response: { code: 'OTP_INVALID' } });
      }
      // The 5th wrong attempt exceeds the limit and burns the code.
      await expect(service.verifyOtp({ phone: PHONE, code: '9999' })).rejects.toMatchObject({
        status: 429,
        response: { code: 'OTP_ATTEMPTS_EXCEEDED' },
      });
      // Even the correct code no longer verifies — a fresh OTP is required.
      await expect(
        service.verifyOtp({ phone: PHONE, code: DEV_OTP_CODE }),
      ).rejects.toMatchObject({ response: { code: 'OTP_EXPIRED' } });
    });

    it('verifies, consumes the code, upserts the customer and issues both tokens', async () => {
      await service.sendOtp({ phone: PHONE });
      const result = requireSession(
        await service.verifyOtp({ phone: PHONE, code: DEV_OTP_CODE }),
      );

      expect(prisma.customer.upsert).toHaveBeenCalledWith({
        where: { phone: PHONE },
        // ADR-1622: a new customer is attributed to tenant #1 (SHIK ROLL).
        create: { phone: PHONE, tenantId: TENANT_ID },
        update: {},
      });
      expect(result.tokenType).toBe('Bearer');
      expect(result.expiresInSeconds).toBe(ACCESS_TOKEN_TTL_SECONDS);
      expect(result.customer).toMatchObject({
        id: CUSTOMER_ID,
        phone: PHONE,
        role: 'CUSTOMER',
      });

      const access = await jwt.verifyAsync(result.accessToken);
      expect(access).toMatchObject({
        sub: CUSTOMER_ID,
        phone: PHONE,
        role: 'CUSTOMER',
        type: 'access',
      });
      const refresh = await jwt.verifyAsync(result.refreshToken);
      expect(refresh).toMatchObject({
        sub: CUSTOMER_ID,
        phone: PHONE,
        role: 'CUSTOMER',
        type: 'refresh',
      });
      expect(refresh.exp - refresh.iat).toBe(REFRESH_TOKEN_TTL_SECONDS);

      // One-time use: the code is consumed and cannot be replayed.
      await expect(otpStore.get(PHONE)).resolves.toBeNull();
      await expect(
        service.verifyOtp({ phone: PHONE, code: DEV_OTP_CODE }),
      ).rejects.toMatchObject({ response: { code: 'OTP_EXPIRED' } });
    });

    it('offers a restore instead of a session when the phone is frozen, creating nothing', async () => {
      const deletedAt = new Date('2026-10-01T00:00:00Z');
      prisma.customer.findUnique.mockResolvedValue(null);
      customers.findFrozenByPhone.mockResolvedValue({ id: CUSTOMER_ID, deletedAt });

      await service.sendOtp({ phone: PHONE });
      const result = requireRestoreOffer(
        await service.verifyOtp({ phone: PHONE, code: DEV_OTP_CODE }),
      );
      expect(result).toMatchObject({
        status: 'RESTORE_AVAILABLE',
        expiresInSeconds: 300,
        deletedAt: deletedAt.toISOString(),
      });
      await expect(
        jwt.verifyAsync(result.restoreToken),
      ).resolves.toMatchObject({ sub: CUSTOMER_ID, type: RESTORE_TOKEN_TYPE });
      // Refusing the offer must not provision a second account on the number.
      expect(prisma.customer.upsert).not.toHaveBeenCalled();
    });

    it('never probes the frozen-account lookup for a live customer', async () => {
      await service.sendOtp({ phone: PHONE });
      await service.verifyOtp({ phone: PHONE, code: DEV_OTP_CODE });

      expect(customers.findFrozenByPhone).not.toHaveBeenCalled();
    });

    it('rejects an expired code (TTL elapsed)', async () => {
      jest.useFakeTimers();
      try {
        await service.sendOtp({ phone: PHONE });
        jest.advanceTimersByTime((OTP_TTL_SECONDS + 1) * 1000);
        await expect(
          service.verifyOtp({ phone: PHONE, code: DEV_OTP_CODE }),
        ).rejects.toMatchObject({ response: { code: 'OTP_EXPIRED' } });
      } finally {
        jest.useRealTimers();
      }
    });
  });

  describe('restoreAccount', () => {
    it('validates the token, unfreezes the account and signs the customer in', async () => {
      const result = await service.restoreAccount('restore-token');

      expect(customers.verifyFlowToken).toHaveBeenCalledWith(
        'restore-token',
        RESTORE_TOKEN_TYPE,
      );
      expect(customers.unfreeze).toHaveBeenCalledWith(CUSTOMER_ID);
      expect(result.customer).toMatchObject({ id: CUSTOMER_ID, phone: PHONE });
      await expect(jwt.verifyAsync(result.accessToken)).resolves.toMatchObject({
        sub: CUSTOMER_ID,
        type: 'access',
      });
    });

    it('propagates a rejected token without touching the account', async () => {
      customers.verifyFlowToken.mockRejectedValue(new Error('bad token'));

      await expect(service.restoreAccount('garbage')).rejects.toThrow('bad token');
      expect(customers.unfreeze).not.toHaveBeenCalled();
    });
  });

  describe('getProfile', () => {
    it('returns the customer profile including the role', async () => {
      const profile = await service.getProfile(CUSTOMER_ID);
      expect(profile).toMatchObject({ id: CUSTOMER_ID, phone: PHONE, role: 'CUSTOMER' });
    });

    it('404 CUSTOMER_NOT_FOUND for an unknown id', async () => {
      prisma.customer.findUnique.mockResolvedValue(null);
      await expect(service.getProfile(CUSTOMER_ID)).rejects.toMatchObject({
        response: { code: 'CUSTOMER_NOT_FOUND' },
      });
    });
  });
});
