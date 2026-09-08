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

describe('CourierJwtAuthGuard', () => {
  let jwt: JwtService;
  let guard: CourierJwtAuthGuard;

  beforeEach(() => {
    jwt = new JwtService({ secret: SECRET });
    guard = new CourierJwtAuthGuard(jwt);
  });

  it('rejects a request without an Authorization header (UNAUTHORIZED)', async () => {
    const { context } = contextFor({});
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'UNAUTHORIZED' },
    });
  });

  it('rejects a malformed Bearer token (TOKEN_INVALID)', async () => {
    const { context } = contextFor({ authorization: 'Bearer not-a-token' });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a customer access token on courier endpoints (TOKEN_INVALID)', async () => {
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
    const refreshLike = await jwt.signAsync({ ...courierPayload, type: 'refresh' });
    const { context } = contextFor({ authorization: `Bearer ${refreshLike}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects an expired courier token (TOKEN_INVALID)', async () => {
    // expiresIn: -1 puts exp one second in the past at signing time.
    const expired = await jwt.signAsync(courierPayload, { expiresIn: -1 });
    const { context } = contextFor({ authorization: `Bearer ${expired}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a token signed with a different secret (TOKEN_INVALID)', async () => {
    const otherJwt = new JwtService({ secret: 'another-secret' });
    const foreign = await otherJwt.signAsync(courierPayload);
    const { context } = contextFor({ authorization: `Bearer ${foreign}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('attaches the courier identity for a valid courier token', async () => {
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
});
