import { ExecutionContext } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { BackofficeMediaGuard, RequestWithBackofficeStaff } from './backoffice-media.guard';

const SECRET = 'backoffice-guard-test-secret';
const STAFF_ID = '9b5f4c4c-0f3d-4e2a-8c1d-2e3f4a5b6c7d';

function contextFor(headers: { authorization?: string }): {
  context: ExecutionContext;
  request: RequestWithBackofficeStaff;
} {
  const request: RequestWithBackofficeStaff = { headers };
  const context = {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  return { context, request };
}

describe('BackofficeMediaGuard (ADR-008)', () => {
  let jwt: JwtService;

  beforeEach(() => {
    jwt = new JwtService({ secret: SECRET });
  });

  function guardWith(allowlist?: string): BackofficeMediaGuard {
    if (allowlist === undefined) {
      delete process.env.BACKOFFICE_STAFF_IDS;
    } else {
      process.env.BACKOFFICE_STAFF_IDS = allowlist;
    }
    return new BackofficeMediaGuard(jwt);
  }

  afterEach(() => {
    delete process.env.BACKOFFICE_STAFF_IDS;
  });

  it('rejects a request without an Authorization header (UNAUTHORIZED)', async () => {
    const { context } = contextFor({});
    await expect(guardWith(STAFF_ID).canActivate(context)).rejects.toMatchObject({
      response: { code: 'UNAUTHORIZED' },
    });
  });

  it('rejects a malformed Bearer token (TOKEN_INVALID)', async () => {
    const { context } = contextFor({ authorization: 'Bearer not-a-token' });
    await expect(guardWith(STAFF_ID).canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects an expired token (TOKEN_INVALID)', async () => {
    const token = await jwt.signAsync(
      { sub: STAFF_ID, role: 'BACKOFFICE', type: 'access' },
      { expiresIn: -10 },
    );
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guardWith(STAFF_ID).canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it.each(['CUSTOMER', 'KITCHEN', 'COURIER'])(
    'rejects a %s token of another bounded context (TOKEN_INVALID)',
    async (role) => {
      const token = await jwt.signAsync({ sub: 'x-1', role, type: 'access' });
      const { context } = contextFor({ authorization: `Bearer ${token}` });
      await expect(guardWith(STAFF_ID).canActivate(context)).rejects.toMatchObject({
        response: { code: 'TOKEN_INVALID' },
      });
    },
  );

  it('rejects a refresh-type backoffice token (TOKEN_INVALID)', async () => {
    const token = await jwt.signAsync({
      sub: STAFF_ID,
      role: 'BACKOFFICE',
      type: 'refresh',
    });
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guardWith(STAFF_ID).canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('denies a valid backoffice token when no provider is configured (403)', async () => {
    const token = await jwt.signAsync({
      sub: STAFF_ID,
      role: 'BACKOFFICE',
      type: 'access',
    });
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guardWith('').canActivate(context)).rejects.toMatchObject({
      response: { code: 'BACKOFFICE_FORBIDDEN' },
    });
    await expect(guardWith(undefined).canActivate(context)).rejects.toMatchObject({
      response: { code: 'BACKOFFICE_FORBIDDEN' },
    });
  });

  it('denies a backoffice subject outside the allowlist (403)', async () => {
    const token = await jwt.signAsync({
      sub: 'someone-else',
      role: 'BACKOFFICE',
      type: 'access',
    });
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guardWith(STAFF_ID).canActivate(context)).rejects.toMatchObject({
      response: { code: 'BACKOFFICE_FORBIDDEN' },
    });
  });

  it('admits an allowlisted backoffice subject and attaches the identity', async () => {
    const token = await jwt.signAsync({
      sub: STAFF_ID,
      role: 'BACKOFFICE',
      type: 'access',
    });
    const { context, request } = contextFor({ authorization: `Bearer ${token}` });
    await expect(
      guardWith(`other-id, ${STAFF_ID} ,third-id`).canActivate(context),
    ).resolves.toBe(true);
    expect(request.backofficeStaff).toEqual({ id: STAFF_ID });
  });
});
