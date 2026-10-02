import {
  ForbiddenException,
  Injectable,
  NestMiddleware,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RequestWithTenant, TenantContext } from './tenant.types';

/** Header the client declares its tenant with. Carries a CODE, not the UUID. */
const TENANT_HEADER = 'x-tenant';

/**
 * Resolves the tenant declared by the client and attaches it to the request as
 * `tenant` (ADR-1622 step 4b).
 *
 * This middleware RESOLVES, it does not REQUIRE. A missing tenant is not an
 * error — no shipped client sends the header yet, most routes are already
 * scoped by a verified guard claim, and the public ones (catalog, health,
 * payment webhooks) must not start failing. A *declared* tenant that does not
 * exist, is soft-deleted or is not ACTIVE is a hard error, because silently
 * ignoring it would answer from the wrong tenant: that is the fail-closed half.
 */
@Injectable()
export class TenantMiddleware
  implements NestMiddleware<RequestWithTenant, unknown>
{
  constructor(private readonly prisma: PrismaService) {}

  async use(
    request: RequestWithTenant,
    _response: unknown,
    next: () => void,
  ): Promise<void> {
    const code = readTenantCode(request);
    if (code) {
      request.tenant = await this.resolve(code);
    }
    next();
  }

  private async resolve(code: string): Promise<TenantContext> {
    const tenant = await this.prisma.tenant.findUnique({
      where: { code },
      select: { id: true, code: true, status: true, deletedAt: true },
    });
    // Soft-deleted answers exactly like never-existed: a 404 code, not a 403.
    // The distinction between "gone" and "paused" is not ours to leak.
    if (!tenant || tenant.deletedAt) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'TENANT_NOT_FOUND',
        message: `Unknown tenant ${code}`,
      });
    }
    if (tenant.status !== 'ACTIVE') {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'TENANT_SUSPENDED',
        message: `Tenant ${code} is not active`,
      });
    }
    return { id: tenant.id, code: tenant.code };
  }
}

/**
 * The tenant the client declared: the X-Tenant header, else the `?tenant=CODE`
 * query fallback. Returns undefined when it declared none.
 *
 * Exported for its own unit spec — this is the only place the header's shape
 * (array values, casing, whitespace) is interpreted.
 */
export function readTenantCode(
  request: RequestWithTenant,
): string | undefined {
  const header = request.headers[TENANT_HEADER];
  const declared = Array.isArray(header) ? header[0] : header;
  const fromQuery = request.query?.tenant;
  const value = declared ?? (typeof fromQuery === 'string' ? fromQuery : undefined);
  const code = value?.trim().toUpperCase();
  return code ? code : undefined;
}
