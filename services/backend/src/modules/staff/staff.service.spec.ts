import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { StaffRole } from '@prisma/client';
import { StaffService } from './staff.service';
import { STAFF_TOKEN_TTL_SECONDS } from './staff.config';
import { __pinRateLimitResetForTests } from '../tenant/pin-rate-limit';

const SECRET = 'staff-service-test-secret';
const PHONE = '+79991234567';
const PIN = '4321';

function makeStaff(overrides: Record<string, unknown> = {}) {
  return {
    id: 'staff-1',
    name: 'Арслан (разработчик)',
    phone: PHONE,
    pinHash: bcrypt.hashSync(PIN, 4),
    role: StaffRole.DEVELOPER,
    brandId: 'brand-1',
    isActive: true,
    createdAt: new Date('2026-09-14T10:00:00Z'),
    updatedAt: new Date('2026-09-14T10:00:00Z'),
    ...overrides,
  };
}

describe('StaffService', () => {
  let prisma: { staff: { findUnique: jest.Mock; findMany: jest.Mock } };
  let jwt: JwtService;
  let service: StaffService;

  beforeEach(() => {
    // The limiter's Map is module state and outlives this spec's instances.
    __pinRateLimitResetForTests();
    prisma = { staff: { findUnique: jest.fn(), findMany: jest.fn() } };
    jwt = new JwtService({ secret: SECRET });
    service = new StaffService(prisma as never, jwt);
  });

  it('rejects an unknown phone with INVALID_CREDENTIALS', async () => {
    prisma.staff.findMany.mockResolvedValue([]);
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: PIN }),
    ).rejects.toMatchObject({
      response: { code: 'INVALID_CREDENTIALS' },
    });
  });

  it('scopes the legacy lookup to an active owning tenant', async () => {
    prisma.staff.findMany.mockResolvedValue([]);
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: PIN }),
    ).rejects.toMatchObject({
      response: { code: 'INVALID_CREDENTIALS' },
    });

    // The database does the filtering, so this asserts the query shape — the
    // suspended-tenant bypass (ADR-1622 blocker A1) is exactly what breaks if
    // the `tenant` filter or `take` goes missing.
    expect(prisma.staff.findMany).toHaveBeenCalledWith({
      where: { phone: PHONE, tenant: { status: 'ACTIVE', deletedAt: null } },
      take: 2,
    });
  });

  it('scopes the declared-tenant lookup to an active owning tenant', async () => {
    prisma.staff.findUnique.mockResolvedValue(null);
    await expect(
      service.authenticateByPin(
        { phone: PHONE, pin: PIN },
        { id: 'tenant-a', code: 'SHIK_ROLL' },
      ),
    ).rejects.toMatchObject({
      response: { code: 'INVALID_CREDENTIALS' },
    });

    // The middleware validated the declared tenant a moment earlier; the row is
    // re-checked in this query so a tenant suspended in between cannot mint a
    // token. Same bypass as the legacy branch, one query later.
    expect(prisma.staff.findUnique).toHaveBeenCalledWith({
      where: {
        tenantId_phone: { tenantId: 'tenant-a', phone: PHONE },
        tenant: { status: 'ACTIVE', deletedAt: null },
      },
    });
  });

  it('rejects a wrong PIN with INVALID_CREDENTIALS', async () => {
    prisma.staff.findMany.mockResolvedValue([makeStaff()]);
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: '0000' }),
    ).rejects.toMatchObject({
      response: { code: 'INVALID_CREDENTIALS' },
    });
  });

  it('rejects a deactivated staff even with the correct PIN', async () => {
    prisma.staff.findMany.mockResolvedValue([makeStaff({ isActive: false })]);
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: PIN }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('issues a scoped staff JWT on a valid login', async () => {
    prisma.staff.findMany.mockResolvedValue([makeStaff()]);
    const result = await service.authenticateByPin({ phone: PHONE, pin: PIN });

    expect(result.tokenType).toBe('Bearer');
    expect(result.expiresInSeconds).toBe(STAFF_TOKEN_TTL_SECONDS);
    expect(result.staff).toEqual({
      id: 'staff-1',
      name: 'Арслан (разработчик)',
      role: 'DEVELOPER',
      brandId: 'brand-1',
    });

    const payload = await jwt.verifyAsync(result.token);
    expect(payload).toMatchObject({
      sub: 'staff-1',
      phone: PHONE,
      role: 'DEVELOPER',
      brandId: 'brand-1',
      type: 'access',
    });
  });

  it('answers 429 TOO_MANY_ATTEMPTS on the sixth failed login', async () => {
    prisma.staff.findMany.mockResolvedValue([]);
    const attempt = () => service.authenticateByPin({ phone: PHONE, pin: PIN });

    for (let i = 0; i < 5; i += 1) {
      await expect(attempt()).rejects.toMatchObject({
        response: { code: 'INVALID_CREDENTIALS' },
      });
    }

    const error = await attempt().catch((e: unknown) => e);
    expect(error).toMatchObject({ response: { code: 'TOO_MANY_ATTEMPTS' } });
    expect((error as { getStatus(): number }).getStatus()).toBe(429);
    // The blocked attempt never reached the lookup.
    expect(prisma.staff.findMany).toHaveBeenCalledTimes(5);
  });

  it('clears the counter after a successful login', async () => {
    prisma.staff.findMany.mockResolvedValue([]);
    for (let i = 0; i < 4; i += 1) {
      await expect(
        service.authenticateByPin({ phone: PHONE, pin: PIN }),
      ).rejects.toMatchObject({ response: { code: 'INVALID_CREDENTIALS' } });
    }

    prisma.staff.findMany.mockResolvedValue([makeStaff()]);
    await service.authenticateByPin({ phone: PHONE, pin: PIN });

    // Four failures plus a success: without the reset the next attempt would
    // already be the sixth of the window and answer 429.
    prisma.staff.findMany.mockResolvedValue([]);
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: PIN }),
    ).rejects.toMatchObject({ response: { code: 'INVALID_CREDENTIALS' } });
  });
});
