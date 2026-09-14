import { ExecutionContext } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { CourierJwtAuthGuard } from './courier-jwt-auth.guard';
import { CourierTokenPayload, RequestWithCourier } from '../couriers.types';

const SECRET = 'courier-guard-test-secret';

function contextFor(headers: { authorization?: string }): {
  context: ExecutionContext;
  request: RequestWithCourier;
} {
  const request: RequestWithCourier = { headers };
  const context = {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  return { context, request };
}

const courierPayload: CourierTokenPayload = {
  sub: 'courier-1',
  phone: '+79991234567',
  branchId: 'branch-1',
  role: 'COURIER',
  type: 'access',
};

/** Minimal Prisma stand-in: only courier.findUnique is used by the guard. */
function prismaWithCourier(courier: unknown) {
  return {
    courier: {
      findUnique: jest.fn().mockResolvedValue(courier),
    },
  } as never;
}

describe('CourierJwtAuthGuard', () => {
  let jwt: JwtService;

  beforeEach(() => {
    jwt = new JwtService({ secret: SECRET });
  });

  it('rejects a request without an Authorization header (UNAUTHORIZED)', async () => {
    const guard = new CourierJwtAuthGuard(jwt, prismaWithCourier(null));
    const { context } = contextFor({});
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'UNAUTHORIZED' },
    });
  });

  it('rejects a malformed Bearer token (TOKEN_INVALID)', async () => {
    const guard = new CourierJwtAuthGuard(jwt, prismaWithCourier(null));
    const { context } = contextFor({ authorization: 'Bearer not-a-token' });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a customer access token on courier endpoints (TOKEN_INVALID)', async () => {
    const guard = new CourierJwtAuthGuard(jwt, prismaWithCourier(null));
    const customerToken = await jwt.signAsync({
      sub: 'customer-1',
      phone: '+79990000000',
      role: 'CUSTOMER',
      type: 'access',
    });
    const { context } = contextFor({ authorization: `Bearer ${customerToken}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a non-access courier token (TOKEN_INVALID)', async () => {
    const guard = new CourierJwtAuthGuard(jwt, prismaWithCourier(null));
    const refreshLike = await jwt.signAsync({ ...courierPayload, type: 'refresh' });
    const { context } = contextFor({ authorization: `Bearer ${refreshLike}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects an expired courier token (TOKEN_INVALID)', async () => {
    const guard = new CourierJwtAuthGuard(jwt, prismaWithCourier(null));
    // expiresIn: -1 puts exp one second in the past at signing time.
    const expired = await jwt.signAsync(courierPayload, { expiresIn: -1 });
    const { context } = contextFor({ authorization: `Bearer ${expired}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a token signed with a different secret (TOKEN_INVALID)', async () => {
    const guard = new CourierJwtAuthGuard(jwt, prismaWithCourier(null));
    const otherJwt = new JwtService({ secret: 'another-secret' });
    const foreign = await otherJwt.signAsync(courierPayload);
    const { context } = contextFor({ authorization: `Bearer ${foreign}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a valid token whose courier row no longer exists (TOKEN_INVALID)', async () => {
    // Prisma returns null: the courier was deleted after the token was issued.
    const guard = new CourierJwtAuthGuard(jwt, prismaWithCourier(null));
    const token = await jwt.signAsync(courierPayload, { expiresIn: 3600 });
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a valid token for a deactivated courier (TOKEN_INVALID)', async () => {
    // The courier row exists but is_active = false: revoke happens on every request.
    const guard = new CourierJwtAuthGuard(
      jwt,
      prismaWithCourier({
        id: 'courier-1',
        phone: '+79991234567',
        branchId: 'branch-1',
        isActive: false,
      }),
    );
    const token = await jwt.signAsync(courierPayload, { expiresIn: 3600 });
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('attaches the courier identity for a valid active courier token', async () => {
    const guard = new CourierJwtAuthGuard(
      jwt,
      prismaWithCourier({
        id: 'courier-1',
        phone: '+79991234567',
        branchId: 'branch-1',
        isActive: true,
      }),
    );
    const token = await jwt.signAsync(courierPayload, { expiresIn: 3600 });
    const { context, request } = contextFor({ authorization: `Bearer ${token}` });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.courier).toEqual({
      id: 'courier-1',
      phone: '+79991234567',
      branchId: 'branch-1',
      role: 'COURIER',
    });
  });

  it('ignores a branchId claim from the token and uses the DB value', async () => {
    // Tampering with branchId in the token must not change the effective branch.
    const guard = new CourierJwtAuthGuard(
      jwt,
      prismaWithCourier({
        id: 'courier-1',
        phone: '+79991234567',
        branchId: 'authoritative-branch',
        isActive: true,
      }),
    );
    const token = await jwt.signAsync(
      { ...courierPayload, branchId: 'attacker-branch' },
      { expiresIn: 3600 },
    );
    const { context, request } = contextFor({ authorization: `Bearer ${token}` });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.courier?.branchId).toBe('authoritative-branch');
  });
});
