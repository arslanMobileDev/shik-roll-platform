import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Customer } from '@prisma/client';
import {
  ACCESS_TOKEN_TTL_SECONDS,
  DEV_OTP_CODE,
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
    delete process.env.SMS_PROVIDER;
  });

  describe('sendOtp', () => {
    it('stores the fixed dev code with the configured TTL when SMS_PROVIDER is not set', async () => {
      const setSpy = jest.spyOn(otpStore, 'set');
      const result = await service.sendOtp({ phone: PHONE });

      expect(result).toEqual({ phone: PHONE, expiresInSeconds: OTP_TTL_SECONDS });
      expect(setSpy).toHaveBeenCalledWith(PHONE, DEV_OTP_CODE, OTP_TTL_SECONDS);
      await expect(otpStore.get(PHONE)).resolves.toBe(DEV_OTP_CODE);
    });

    it('generates a random 4-digit code when SMS_PROVIDER is set', async () => {
      process.env.SMS_PROVIDER = 'stub';
      const result = await service.sendOtp({ phone: PHONE });

      expect(result.expiresInSeconds).toBe(OTP_TTL_SECONDS);
      const code = await otpStore.get(PHONE);
      expect(code).toMatch(/^\d{4}$/);
    });
  });

  describe('verifyOtp', () => {
    it('rejects when no code was requested (401 OTP_EXPIRED)', async () => {
      await expect(service.verifyOtp({ phone: PHONE, code: '1234' })).rejects.toMatchObject({
        response: { code: 'OTP_EXPIRED' },
      });
      await expect(
        service.verifyOtp({ phone: PHONE, code: '1234' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects a wrong code (401 OTP_INVALID) and keeps the stored code', async () => {
      await service.sendOtp({ phone: PHONE });
      await expect(service.verifyOtp({ phone: PHONE, code: '9999' })).rejects.toMatchObject({
        response: { code: 'OTP_INVALID' },
      });
      // The stored code survives a failed attempt.
      await expect(otpStore.get(PHONE)).resolves.toBe(DEV_OTP_CODE);
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
      expect(result.customer).toMatchObject({ id: CUSTOMER_ID, phone: PHONE });

      const access = await jwt.verifyAsync(result.accessToken);
      expect(access).toMatchObject({ sub: CUSTOMER_ID, phone: PHONE, type: 'access' });
      const refresh = await jwt.verifyAsync(result.refreshToken);
      expect(refresh).toMatchObject({ sub: CUSTOMER_ID, phone: PHONE, type: 'refresh' });
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
    it('returns the customer profile', async () => {
      const profile = await service.getProfile(CUSTOMER_ID);
      expect(profile).toMatchObject({ id: CUSTOMER_ID, phone: PHONE });
    });

    it('404 CUSTOMER_NOT_FOUND for an unknown id', async () => {
      prisma.customer.findUnique.mockResolvedValue(null);
      await expect(service.getProfile(CUSTOMER_ID)).rejects.toMatchObject({
        response: { code: 'CUSTOMER_NOT_FOUND' },
      });
    });
  });
});
