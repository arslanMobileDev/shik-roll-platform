import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { JwtAuthGuard, OptionalJwtAuthGuard } from './jwt-auth.guard';
import { RequestWithCustomer } from '../auth.types';

const SECRET = 'guard-test-secret';

function contextFor(headers: { authorization?: string }): {
  context: ExecutionContext;
  request: RequestWithCustomer;
} {
  const request: RequestWithCustomer = { headers };
  const context = {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  return { context, request };
}

describe('JwtAuthGuard', () => {
  let jwt: JwtService;
  let guard: JwtAuthGuard;

  beforeEach(() => {
    jwt = new JwtService({ secret: SECRET });
    guard = new JwtAuthGuard(jwt);
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

  it('rejects a refresh token used as an access token (TOKEN_INVALID)', async () => {
    const refresh = await jwt.signAsync({ sub: 'c1', phone: '+79990000000', type: 'refresh' });
    const { context } = contextFor({ authorization: `Bearer ${refresh}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('attaches the customer identity for a valid access token', async () => {
    const token = await jwt.signAsync({ sub: 'c1', phone: '+79990000000', type: 'access' });
    const { context, request } = contextFor({ authorization: `Bearer ${token}` });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.customer).toEqual({ id: 'c1', phone: '+79990000000' });
  });
});

describe('OptionalJwtAuthGuard', () => {
  let jwt: JwtService;
  let guard: OptionalJwtAuthGuard;

  beforeEach(() => {
    jwt = new JwtService({ secret: SECRET });
    guard = new OptionalJwtAuthGuard(jwt);
  });

  it('passes anonymous requests through without a customer', async () => {
    const { context, request } = contextFor({});
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.customer).toBeUndefined();
  });

  it('still rejects an invalid token when one is supplied', async () => {
    const { context } = contextFor({ authorization: 'Bearer garbage' });
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('attaches the customer identity for a valid token', async () => {
    const token = await jwt.signAsync({ sub: 'c2', phone: '+79991111111', type: 'access' });
    const { context, request } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.customer).toEqual({ id: 'c2', phone: '+79991111111' });
  });
});
