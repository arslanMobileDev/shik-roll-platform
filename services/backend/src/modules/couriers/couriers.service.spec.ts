import * as bcrypt from 'bcryptjs';
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { CouriersService } from './couriers.service';
import { COURIER_TOKEN_TTL_SECONDS } from './couriers.config';
import { CourierTokenPayload } from './couriers.types';

const SECRET = 'courier-service-test-secret';

function prismaMock() {
  return {
    courier: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
    branch: { findFirst: jest.fn() },
    brand: { findFirst: jest.fn() },
  };
}

const existingCourier = {
  id: 'courier-1',
  name: 'Курьер 4567',
  phone: '+79991234567',
  pinHash: '',
  brandId: 'brand-1',
  branchId: 'branch-1',
  isAvailable: true,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('CouriersService.authenticateByPin', () => {
  let prisma: ReturnType<typeof prismaMock>;
  let jwt: JwtService;
  let service: CouriersService;

  beforeEach(() => {
    prisma = prismaMock();
    jwt = new JwtService({ secret: SECRET });
    service = new CouriersService(prisma as any, jwt);
  });

  it('registers a new courier with a bcrypt-hashed PIN and returns a signed JWT', async () => {
    prisma.courier.findUnique.mockResolvedValue(null);
    prisma.branch.findFirst.mockResolvedValue({ id: 'branch-1' });
    prisma.brand.findFirst.mockResolvedValue({ id: 'brand-1' });
    prisma.courier.create.mockImplementation(async ({ data }) => ({
      ...existingCourier,
      ...data,
    }));

    const result = await service.authenticateByPin({
      phone: existingCourier.phone,
      pin: '1234',
    });

    // PIN is stored only as a bcrypt hash, never in plaintext.
    const { pinHash } = prisma.courier.create.mock.calls[0][0].data;
    expect(pinHash).toMatch(/^\$2[aby]\$/);
    expect(pinHash).not.toBe('1234');
    await expect(bcrypt.compare('1234', pinHash)).resolves.toBe(true);
    await expect(bcrypt.compare('9999', pinHash)).resolves.toBe(false);

    // The token is a real signed JWT carrying courierId, branch and role.
    expect(result.token).not.toContain('courier-session-');
    expect(result.tokenType).toBe('Bearer');
    expect(result.expiresInSeconds).toBe(COURIER_TOKEN_TTL_SECONDS);

    const payload = await jwt.verifyAsync<CourierTokenPayload & { iat: number; exp: number }>(
      result.token,
    );
    expect(payload.sub).toBe(existingCourier.id);
    expect(payload.phone).toBe(existingCourier.phone);
    expect(payload.branchId).toBe('branch-1');
    expect(payload.role).toBe('COURIER');
    expect(payload.type).toBe('access');
    expect(payload.exp - payload.iat).toBe(COURIER_TOKEN_TTL_SECONDS);
  });

  it('authenticates an existing courier with the correct PIN', async () => {
    const pinHash = await bcrypt.hash('1234', 4);
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash });

    const result = await service.authenticateByPin({
      phone: existingCourier.phone,
      pin: '1234',
    });

    const payload = await jwt.verifyAsync<CourierTokenPayload>(result.token);
    expect(payload.sub).toBe('courier-1');
    expect(payload.branchId).toBe('branch-1');
    expect(prisma.courier.update).not.toHaveBeenCalled();
  });

  it('rejects a wrong PIN with UnauthorizedException', async () => {
    const pinHash = await bcrypt.hash('1234', 4);
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash });

    await expect(
      service.authenticateByPin({ phone: existingCourier.phone, pin: '9999' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('migrates a legacy plaintext pinHash to bcrypt on successful login', async () => {
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash: '1234' });

    const result = await service.authenticateByPin({
      phone: existingCourier.phone,
      pin: '1234',
    });

    expect(result.token).toBeDefined();
    expect(prisma.courier.update).toHaveBeenCalledTimes(1);
    const updateArgs = prisma.courier.update.mock.calls[0][0];
    expect(updateArgs.where).toEqual({ id: 'courier-1' });
    expect(updateArgs.data.pinHash).toMatch(/^\$2[aby]\$/);
    await expect(bcrypt.compare('1234', updateArgs.data.pinHash)).resolves.toBe(true);
  });

  it('rejects a wrong PIN on a legacy plaintext row without migrating it', async () => {
    prisma.courier.findUnique.mockResolvedValue({ ...existingCourier, pinHash: '1234' });

    await expect(
      service.authenticateByPin({ phone: existingCourier.phone, pin: '9999' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.courier.update).not.toHaveBeenCalled();
  });

  it('fails registration when branch/brand configuration is missing', async () => {
    prisma.courier.findUnique.mockResolvedValue(null);
    prisma.branch.findFirst.mockResolvedValue(null);
    prisma.brand.findFirst.mockResolvedValue({ id: 'brand-1' });

    await expect(
      service.authenticateByPin({ phone: '+79990000000', pin: '1234' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.courier.create).not.toHaveBeenCalled();
  });
});
