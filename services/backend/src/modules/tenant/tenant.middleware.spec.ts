import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantMiddleware, readTenantCode } from './tenant.middleware';
import { RequestWithTenant } from './tenant.types';

const TENANT = { id: 'tenant-1', code: 'SHIK_ROLL', status: 'ACTIVE' };

function request(init: Partial<RequestWithTenant> = {}): RequestWithTenant {
  return { headers: {}, ...init };
}

describe('readTenantCode (variant A strictness)', () => {
  it('returns undefined when neither header nor query is present', () => {
    expect(readTenantCode({ headers: {} })).toBeUndefined();
  });

  it('resolves the X-Tenant header (a code, not a UUID), trims and uppercases', () => {
    const code = readTenantCode({ headers: { 'x-tenant': ' shik_roll ' } });
    expect(code).toBe('SHIK_ROLL');
  });

  it('falls back to ?tenant=CODE when the header is absent', () => {
    const code = readTenantCode({
      headers: {},
      query: { tenant: 'shik_roll' },
    });
    expect(code).toBe('SHIK_ROLL');
  });

  it('accepts matching header and query (case-insensitive)', () => {
    const code = readTenantCode({
      headers: { 'x-tenant': 'shik_roll' },
      query: { tenant: 'SHIK_ROLL' },
    });
    expect(code).toBe('SHIK_ROLL');
  });

  it('returns header code when ?tenant is blank', () => {
    const code = readTenantCode({
      headers: { 'x-tenant': 'SHIK_ROLL' },
      query: { tenant: '' },
    });
    expect(code).toBe('SHIK_ROLL');
  });

  it('rejects an array X-Tenant header (duplicate) with 400 TENANT_INVALID', () => {
    try {
      readTenantCode({ headers: { 'x-tenant': ['SHIK_ROLL', 'OTHER'] } });
      fail('expected throw');
    } catch (e) {
      expect(e).toBeInstanceOf(BadRequestException);
      expect((e as BadRequestException).getResponse()).toMatchObject({
        code: 'TENANT_INVALID',
      });
    }
  });

  it('rejects ?tenant as array with 400 TENANT_INVALID', () => {
    try {
      readTenantCode({
        headers: {},
        query: { tenant: ['SHIK_ROLL', 'OTHER'] },
      });
      fail('expected throw');
    } catch (e) {
      expect(e).toBeInstanceOf(BadRequestException);
      expect((e as BadRequestException).getResponse()).toMatchObject({
        code: 'TENANT_INVALID',
      });
    }
  });

  it('rejects ?tenant as object (?tenant[a]=b) with 400 TENANT_INVALID', () => {
    try {
      readTenantCode({ headers: {}, query: { tenant: { a: 'b' } } });
      fail('expected throw');
    } catch (e) {
      expect(e).toBeInstanceOf(BadRequestException);
      expect((e as BadRequestException).getResponse()).toMatchObject({
        code: 'TENANT_INVALID',
      });
    }
  });

  it('rejects blank X-Tenant without query with 400 TENANT_INVALID', () => {
    expect(() =>
      readTenantCode({ headers: { 'x-tenant': '' } }),
    ).toThrow(BadRequestException);
  });

  it('rejects whitespace-only X-Tenant without query with 400 TENANT_INVALID', () => {
    expect(() =>
      readTenantCode({ headers: { 'x-tenant': '   ' } }),
    ).toThrow(BadRequestException);
  });

  it('rejects blank X-Tenant even when ?tenant is valid (variant A) with 400', () => {
    expect(() =>
      readTenantCode({
        headers: { 'x-tenant': '' },
        query: { tenant: 'SHIK_ROLL' },
      }),
    ).toThrow(BadRequestException);
  });

  it('rejects conflicting X-Tenant and ?tenant with 400 TENANT_CONFLICT', () => {
    try {
      readTenantCode({
        headers: { 'x-tenant': 'SHIK_ROLL' },
        query: { tenant: 'OTHER' },
      });
      fail('expected throw');
    } catch (e) {
      expect(e).toBeInstanceOf(BadRequestException);
      expect((e as BadRequestException).getResponse()).toMatchObject({
        code: 'TENANT_CONFLICT',
      });
    }
  });

  it('rejects duplicate X-Tenant seen via rawHeaders — 400 TENANT_INVALID', () => {
    expect(() =>
      readTenantCode({
        headers: { 'x-tenant': 'A, B' },
        rawHeaders: ['X-Tenant', 'A', 'X-Tenant', 'B'],
      }),
    ).toThrow(BadRequestException);
  });

  it('rejects a comma-glued X-Tenant even without rawHeaders — 400', () => {
    expect(() =>
      readTenantCode({ headers: { 'x-tenant': 'A, B' } }),
    ).toThrow(BadRequestException);
  });

  it('rejects ?tenant[a]=b (simple parser flattens to key "tenant[a]") — 400', () => {
    expect(() =>
      readTenantCode({ headers: {}, query: { 'tenant[a]': 'b' } }),
    ).toThrow(BadRequestException);
  });

  it('rejects ?tenant[]=A (bracket-empty form) — 400', () => {
    expect(() =>
      readTenantCode({ headers: {}, query: { 'tenant[]': 'A' } }),
    ).toThrow(BadRequestException);
  });

  it('does not touch an unrelated query key starting with "tenant" — OK', () => {
    const code = readTenantCode({
      headers: { 'x-tenant': 'SHIK_ROLL' },
      query: { tenantNote: 'x' },
    });
    expect(code).toBe('SHIK_ROLL');
  });
});

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

  it('resolves the X-Tenant header and attaches the tenant context', async () => {
    const req = request({ headers: { 'x-tenant': ' shik_roll ' } });
    await middleware.use(req, {}, next);

    expect(prisma.tenant.findUnique).toHaveBeenCalledWith({
      where: { code: 'SHIK_ROLL' },
      select: { id: true, code: true, status: true, deletedAt: true },
    });
    expect(req.tenant).toEqual({ id: 'tenant-1', code: 'SHIK_ROLL' });
    expect(next).toHaveBeenCalled();
  });

  it('propagates the 400 from a repeated X-Tenant header without calling next', async () => {
    const req = request({ headers: { 'x-tenant': ['SHIK_ROLL', 'OTHER'] } });

    await expect(middleware.use(req, {}, next)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.tenant.findUnique).not.toHaveBeenCalled();
    expect(next).not.toHaveBeenCalled();
  });

  it('propagates the 400 from a non-string ?tenant= without calling next', async () => {
    const req = request({ query: { tenant: ['SHIK_ROLL', 'OTHER'] } });

    await expect(middleware.use(req, {}, next)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.tenant.findUnique).not.toHaveBeenCalled();
    expect(next).not.toHaveBeenCalled();
  });

  it('propagates the 400 from a header/query conflict without calling next', async () => {
    const req = request({
      headers: { 'x-tenant': 'SHIK_ROLL' },
      query: { tenant: 'OTHER' },
    });

    await expect(middleware.use(req, {}, next)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(next).not.toHaveBeenCalled();
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
