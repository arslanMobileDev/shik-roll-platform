import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Customer } from '@prisma/client';
import {
  ACCESS_TOKEN_TTL_SECONDS,
  DEV_OTP_CODE,
  OTP_MAX_ATTEMPTS,
  OTP_SEND_COOLDOWN_SECONDS,
  OTP_TTL_SECONDS,
  REFRESH_TOKEN_TTL_SECONDS,
} from './auth.config';
import { AuthService } from './auth.service';
import { InMemoryOtpStore } from './otp-store.service';

const PHONE = '+79991234567';
const CUSTOMER_ID = '11111111-1111-1111-1111-111111111111';

function makeCustomer(phone: string = PHONE): Customer {
  return {
    id: CUSTOMER_ID,
    phone,
    name: null,
    email: null,
    role: 'CUSTOMER',
    createdAt: new Date('2026-09-04T10:00:00Z'),
    updatedAt: new Date('2026-09-04T10:00:00Z'),
  };
}

describe('AuthService', () => {
  let service: AuthService;
  let otpStore: InMemoryOtpStore;
  let jwt: JwtService;
  let prisma: {
    customer: { upsert: jest.Mock; findUnique: jest.Mock };
  };
  let originalNodeEnv: string | undefined;

  beforeEach(() => {
    otpStore = new InMemoryOtpStore();
    jwt = new JwtService({ secret: 'unit-test-secret' });
    prisma = {
      customer: {
        upsert: jest.fn().mockResolvedValue(makeCustomer()),
        findUnique: jest.fn().mockResolvedValue(makeCustomer()),
      },
    };
    service = new AuthService(otpStore, jwt, prisma as never);
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

    it('forces the fixed dev code in production when DEV_OTP=true', async () => {
      process.env.NODE_ENV = 'production';
      process.env.DEV_OTP = 'true';
      const result = await service.sendOtp({ phone: PHONE });

      expect(result.devCode).toBe(DEV_OTP_CODE);
      await expect(otpStore.get(PHONE)).resolves.toMatchObject({ code: DEV_OTP_CODE });
    });

    it('generates a random 4-digit code in production and never returns it', async () => {
      process.env.NODE_ENV = 'production';
      process.env.SMS_PROVIDER = 'stub';
      const result = await service.sendOtp({ phone: PHONE });

      expect(result.expiresInSeconds).toBe(OTP_TTL_SECONDS);
      expect(result.devCode).toBeUndefined();
      const entry = await otpStore.get(PHONE);
      expect(entry?.code).toMatch(/^\d{4}$/);
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
      const result = await service.verifyOtp({ phone: PHONE, code: DEV_OTP_CODE });

      expect(prisma.customer.upsert).toHaveBeenCalledWith({
        where: { phone: PHONE },
        create: { phone: PHONE },
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
