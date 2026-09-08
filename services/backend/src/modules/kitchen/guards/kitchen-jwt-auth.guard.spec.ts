import { ExecutionContext } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../../prisma/prisma.service';
import { KitchenJwtAuthGuard } from './kitchen-jwt-auth.guard';
import { KitchenTokenPayload, RequestWithKitchen } from '../kitchen.types';

const SECRET = 'kitchen-guard-test-secret';

const TERMINAL = {
  id: 'terminal-1',
  code: 'KDS-01',
  name: 'Kitchen Terminal 1',
  branchId: 'branch-1',
  isActive: true,
};

function contextFor(headers: { authorization?: string }): {
  context: ExecutionContext;
  request: RequestWithKitchen;
} {
  const request: RequestWithKitchen = { headers };
  const context = {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  return { context, request };
}

const kitchenPayload: KitchenTokenPayload = {
  sub: TERMINAL.id,
  branchId: TERMINAL.branchId,
  role: 'KITCHEN',
  type: 'access',
};

describe('KitchenJwtAuthGuard', () => {
  let jwt: JwtService;
  let prisma: { kitchenTerminal: { findUnique: jest.Mock } };
  let guard: KitchenJwtAuthGuard;

  beforeEach(() => {
    jwt = new JwtService({ secret: SECRET });
    prisma = {
      kitchenTerminal: {
        findUnique: jest.fn().mockResolvedValue(TERMINAL),
      },
    };
    guard = new KitchenJwtAuthGuard(jwt, prisma as unknown as PrismaService);
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

  it('rejects a courier access token on kitchen endpoints (TOKEN_INVALID)', async () => {
    const courierToken = await jwt.signAsync({
      sub: 'courier-1',
      phone: '+79991234567',
      branchId: 'branch-1',
      role: 'COURIER',
      type: 'access',
    });
    const { context } = contextFor({ authorization: `Bearer ${courierToken}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a customer access token on kitchen endpoints (TOKEN_INVALID)', async () => {
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

  it('rejects a non-access kitchen token (TOKEN_INVALID)', async () => {
    const refreshLike = await jwt.signAsync({ ...kitchenPayload, type: 'refresh' });
    const { context } = contextFor({ authorization: `Bearer ${refreshLike}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects an expired kitchen token (TOKEN_INVALID)', async () => {
    // expiresIn: -1 puts exp one second in the past at signing time.
    const expired = await jwt.signAsync(kitchenPayload, { expiresIn: -1 });
    const { context } = contextFor({ authorization: `Bearer ${expired}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TOKEN_INVALID' },
    });
  });

  it('rejects a deactivated terminal with a still-valid token (TERMINAL_INACTIVE)', async () => {
    prisma.kitchenTerminal.findUnique.mockResolvedValue({
      ...TERMINAL,
      isActive: false,
    });
    const token = await jwt.signAsync(kitchenPayload, { expiresIn: 3600 });
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TERMINAL_INACTIVE' },
    });
  });

  it('rejects a token of an unknown terminal (TERMINAL_INACTIVE)', async () => {
    prisma.kitchenTerminal.findUnique.mockResolvedValue(null);
    const token = await jwt.signAsync(kitchenPayload, { expiresIn: 3600 });
    const { context } = contextFor({ authorization: `Bearer ${token}` });
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      response: { code: 'TERMINAL_INACTIVE' },
    });
  });

  it('attaches the DB-authoritative terminal identity for a valid kitchen token', async () => {
    const token = await jwt.signAsync(kitchenPayload, { expiresIn: 3600 });
    const { context, request } = contextFor({ authorization: `Bearer ${token}` });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(prisma.kitchenTerminal.findUnique).toHaveBeenCalledWith({
      where: { id: TERMINAL.id },
    });
    expect(request.kitchenTerminal).toEqual({
      id: TERMINAL.id,
      code: TERMINAL.code,
      name: TERMINAL.name,
      branchId: TERMINAL.branchId,
      role: 'KITCHEN',
    });
  });
});
