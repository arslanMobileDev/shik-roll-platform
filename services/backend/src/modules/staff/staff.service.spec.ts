import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { StaffRole } from '@prisma/client';
import { StaffService } from './staff.service';
import { STAFF_TOKEN_TTL_SECONDS } from './staff.config';

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
  let prisma: { staff: { findUnique: jest.Mock } };
  let jwt: JwtService;
  let service: StaffService;

  beforeEach(() => {
    prisma = { staff: { findUnique: jest.fn() } };
    jwt = new JwtService({ secret: SECRET });
    service = new StaffService(prisma as never, jwt);
  });

  it('rejects an unknown phone with INVALID_CREDENTIALS', async () => {
    prisma.staff.findUnique.mockResolvedValue(null);
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: PIN }),
    ).rejects.toMatchObject({
      response: { code: 'INVALID_CREDENTIALS' },
    });
  });

  it('rejects a wrong PIN with INVALID_CREDENTIALS', async () => {
    prisma.staff.findUnique.mockResolvedValue(makeStaff());
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: '0000' }),
    ).rejects.toMatchObject({
      response: { code: 'INVALID_CREDENTIALS' },
    });
  });

  it('rejects a deactivated staff even with the correct PIN', async () => {
    prisma.staff.findUnique.mockResolvedValue(makeStaff({ isActive: false }));
    await expect(
      service.authenticateByPin({ phone: PHONE, pin: PIN }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('issues a scoped staff JWT on a valid login', async () => {
    prisma.staff.findUnique.mockResolvedValue(makeStaff());
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
});
