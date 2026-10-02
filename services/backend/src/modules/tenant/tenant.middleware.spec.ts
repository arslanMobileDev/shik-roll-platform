import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantMiddleware } from './tenant.middleware';
import { RequestWithTenant } from './tenant.types';

const TENANT = { id: 'tenant-1', code: 'SHIK_ROLL', status: 'ACTIVE' };

function request(init: Partial<RequestWithTenant> = {}): RequestWithTenant {
  return { headers: {}, ...init };
}

describe('TenantMiddleware', () => {
  let prisma: { tenant: { findUnique: jest.Mock } };
  let middleware: TenantMiddleware;
  let next: jest.Mock;

  beforeEach(() => {
    prisma = { tenant: { findUnique: jest.fn().mockResolvedValue(TENANT) } };
    middleware = new TenantMiddleware(prisma as unknown as PrismaService);
    next = jest.fn();
  });

  it('leaves the request unscoped when no tenant is declared', async () => {
    const req = request({ query: {} });
    await middleware.use(req, {}, next);

    expect(req.tenant).toBeUndefined();
    expect(prisma.tenant.findUnique).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalled();
  });

  it('resolves the X-Tenant header (a code, not a UUID) and uppercases it', async () => {
    const req = request({ headers: { 'x-tenant': ' shik_roll ' } });
    await middleware.use(req, {}, next);

    expect(prisma.tenant.findUnique).toHaveBeenCalledWith({
      where: { code: 'SHIK_ROLL' },
      select: { id: true, code: true, status: true, deletedAt: true },
    });
    expect(req.tenant).toEqual({ id: 'tenant-1', code: 'SHIK_ROLL' });
  });

  it('takes the first value when the header is repeated', async () => {
    const req = request({ headers: { 'x-tenant': ['SHIK_ROLL', 'OTHER'] } });
    await middleware.use(req, {}, next);

    expect(req.tenant?.code).toBe('SHIK_ROLL');
  });

  it('falls back to ?tenant=CODE, and the header wins over it', async () => {
    const viaQuery = request({ query: { tenant: 'shik_roll' } });
    await middleware.use(viaQuery, {}, next);
    expect(viaQuery.tenant?.code).toBe('SHIK_ROLL');

    prisma.tenant.findUnique.mockClear();
    const both = request({
      headers: { 'x-tenant': 'OTHER' },
      query: { tenant: 'SHIK_ROLL' },
    });
    await middleware.use(both, {}, next);
    expect(prisma.tenant.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { code: 'OTHER' } }),
    );
  });

  it('ignores a non-string ?tenant= (e.g. a repeated query param)', async () => {
    const req = request({ query: { tenant: ['SHIK_ROLL', 'OTHER'] } });
    await middleware.use(req, {}, next);

    expect(req.tenant).toBeUndefined();
    expect(prisma.tenant.findUnique).not.toHaveBeenCalled();
  });

  it('404s on a declared tenant that does not exist', async () => {
    prisma.tenant.findUnique.mockResolvedValue(null);
    const req = request({ headers: { 'x-tenant': 'NOPE' } });

    await expect(middleware.use(req, {}, next)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(req.tenant).toBeUndefined();
    expect(next).not.toHaveBeenCalled();
  });

  it('404s on a soft-deleted tenant even while its status is still ACTIVE', async () => {
    prisma.tenant.findUnique.mockResolvedValue({
      ...TENANT,
      deletedAt: new Date('2026-10-02T00:00:00Z'),
    });
    const req = request({ headers: { 'x-tenant': 'SHIK_ROLL' } });

    await expect(middleware.use(req, {}, next)).rejects.toMatchObject({
      response: { code: 'TENANT_NOT_FOUND' },
    });
    expect(req.tenant).toBeUndefined();
    expect(next).not.toHaveBeenCalled();
  });

  it('403s on a declared tenant that is not ACTIVE', async () => {
    prisma.tenant.findUnique.mockResolvedValue({
      ...TENANT,
      status: 'SUSPENDED',
    });
    const req = request({ headers: { 'x-tenant': 'SHIK_ROLL' } });

    await expect(middleware.use(req, {}, next)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(next).not.toHaveBeenCalled();
  });
});
