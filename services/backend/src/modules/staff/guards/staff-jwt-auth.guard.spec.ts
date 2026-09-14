import { ExecutionContext } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { StaffRole } from '@prisma/client';
import { StaffJwtAuthGuard } from './staff-jwt-auth.guard';
import { RequestWithStaff, StaffTokenPayload } from '../staff.types';

const SECRET = 'staff-guard-test-secret';

function contextFor(headers: { authorization?: string }): {
  context: ExecutionContext;
  request: RequestWithStaff;
} {
  const request: RequestWithStaff = { headers };
  const context = {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  return { context, request };
}

const staffPayload: StaffTokenPayload = {
  sub: 'staff-1',
  phone: '+79991234567',
  role: StaffRole.DEVELOPER,
  brandId: 'brand-1',
  type: 'access',
};

function prismaWithStaff(row: unknown) {
  return {
    staff: { findUnique: jest.fn().mockResolvedValue(row) },
  } as never;
}

describe('StaffJwtAuthGuard', () => {
  let jwt: JwtService;

  beforeEach(() => {
    jwt = new JwtService({ secret: SECRET });
  });

  it('rejects a request without an Authorization header (UNAUTHORIZED)', async () => {
    const guard = new StaffJwtAuthGuard(jwt, prismaWithStaff(null));
    await expect(guard.canActivate(contextFor({}).context)).rejects.toMatchObject({
      response: { code: 'UNAUTHORIZED' },
    });
  });

  it('rejects a malformed Bearer token (TOKEN_INVALID)', async () => {
    const guard = new StaffJwtAuthGuard(jwt, prismaWithStaff(null));
    await expect(
      guard.canActivate(contextFor({ authorization: 'Bearer not-a-token' }).context),
    ).rejects.toMatchObject({ response: { code: 'TOKEN_INVALID' } });
  });

  it('rejects a customer token on staff endpoints (TOKEN_INVALID)', async () => {
    const guard = new StaffJwtAuthGuard(jwt, prismaWithStaff(null));
    const customerToken = await jwt.signAsync({
      sub: 'customer-1',
      phone: '+79990000000',
      role: 'CUSTOMER',
      type: 'access',
    });
    await expect(
      guard.canActivate(contextFor({ authorization: `Bearer ${customerToken}` }).context),
    ).rejects.toMatchObject({ response: { code: 'TOKEN_INVALID' } });
  });

  it('rejects a valid token for a missing staff row (TOKEN_INVALID)', async () => {
    const guard = new StaffJwtAuthGuard(jwt, prismaWithStaff(null));
    const token = await jwt.signAsync(staffPayload, { expiresIn: 3600 });
    await expect(
      guard.canActivate(contextFor({ authorization: `Bearer ${token}` }).context),
    ).rejects.toMatchObject({ response: { code: 'TOKEN_INVALID' } });
  });

  it('rejects a valid token for a deactivated staff (TOKEN_INVALID)', async () => {
    const guard = new StaffJwtAuthGuard(
      jwt,
      prismaWithStaff({
        id: 'staff-1',
        phone: '+79991234567',
        role: StaffRole.DEVELOPER,
        brandId: 'brand-1',
        isActive: false,
      }),
    );
    const token = await jwt.signAsync(staffPayload, { expiresIn: 3600 });
    await expect(
      guard.canActivate(contextFor({ authorization: `Bearer ${token}` }).context),
    ).rejects.toMatchObject({ response: { code: 'TOKEN_INVALID' } });
  });

  it('attaches the staff actor for a valid active token', async () => {
    const guard = new StaffJwtAuthGuard(
      jwt,
      prismaWithStaff({
        id: 'staff-1',
        phone: '+79991234567',
        role: StaffRole.DEVELOPER,
        brandId: 'brand-1',
        isActive: true,
      }),
    );
    const token = await jwt.signAsync(staffPayload, { expiresIn: 3600 });
    const { context, request } = contextFor({ authorization: `Bearer ${token}` });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.staff).toEqual({
      id: 'staff-1',
      phone: '+79991234567',
      role: StaffRole.DEVELOPER,
      brandId: 'brand-1',
    });
  });
});
