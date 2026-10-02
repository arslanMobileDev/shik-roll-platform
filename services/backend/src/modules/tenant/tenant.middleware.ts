import {
  BadRequestException,
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
 *
 * Since step 4 (C2) the *shape* of the declaration is also fail-closed:
 * a malformed header or query is 400, not silently downgraded to "none".
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
 * Strictness policy (ADR-1622 step 4, variant A):
 * - Header present but blank -> 400 TENANT_INVALID, even when ?tenant= would
 *   have been valid. A client that names the tenant must name it correctly.
 * - Duplicate declarations -> 400 TENANT_INVALID. Node glues repeated
 *   X-Tenant headers into a single "A, B" string, so the shape is detected
 *   both from `rawHeaders` (authoritative) and from a comma in the value.
 * - `?tenant=A&tenant=B` (array) and `?tenant=a[b]` / `?tenant[]=A`
 *   (bracket forms, which the simple parser flattens into sibling keys
 *   `tenant[a]` / `tenant[]`) -> 400 TENANT_INVALID.
 * - Header and query that disagree -> 400 TENANT_CONFLICT. Not knowable.
 * - Header absent + valid query -> OK, use the query.
 * - Neither present -> undefined, middleware leaves the request unscoped.
 *
 * Exported for its own unit spec — this is the only place the header's shape
 * (array values, casing, whitespace, glued values) is interpreted.
 */
export function readTenantCode(
  request: RequestWithTenant,
): string | undefined {
  const hasHeader = Object.prototype.hasOwnProperty.call(
    request.headers,
    TENANT_HEADER,
  );
  const header = request.headers[TENANT_HEADER];
  const rawHeaders = request.rawHeaders;
  const fromQuery = request.query?.tenant;

  // 1a. Duplicate X-Tenant, authoritative detection via rawHeaders.
  if (rawHeaders) {
    let seen = 0;
    for (let i = 0; i < rawHeaders.length; i += 2) {
      if (rawHeaders[i]?.toLowerCase() === TENANT_HEADER) seen += 1;
    }
    if (seen > 1) {
      throw new BadRequestException({
        statusCode: 400,
        code: 'TENANT_INVALID',
        message: 'X-Tenant must be a single value',
      });
    }
  }

  // 1b. Duplicate X-Tenant, defensive detection from the glued value.
  if (Array.isArray(header)) {
    throw new BadRequestException({
      statusCode: 400,
      code: 'TENANT_INVALID',
      message: 'X-Tenant must be a single value',
    });
  }
  if (typeof header === 'string' && header.includes(',')) {
    throw new BadRequestException({
      statusCode: 400,
      code: 'TENANT_INVALID',
      message: 'X-Tenant must be a single value',
    });
  }

  // 2. Bracket-form `?tenant[...]` — the simple parser surfaces it as a
  //    sibling key, so `query.tenant` stays undefined and the strictness
  //    below would never see it. Refuse any such sibling explicitly.
  if (request.query) {
    for (const key of Object.keys(request.query)) {
      if (key !== 'tenant' && key.startsWith('tenant[')) {
        throw new BadRequestException({
          statusCode: 400,
          code: 'TENANT_INVALID',
          message: '?tenant must be a single string',
        });
      }
    }
  }

  // 3. `?tenant=A&tenant=B` — the parser hands back an array.
  if (fromQuery !== undefined && typeof fromQuery !== 'string') {
    throw new BadRequestException({
      statusCode: 400,
      code: 'TENANT_INVALID',
      message: '?tenant must be a single string',
    });
  }

  const headerCode =
    typeof header === 'string' && header.trim()
      ? header.trim().toUpperCase()
      : undefined;
  const queryCode =
    typeof fromQuery === 'string' && fromQuery.trim()
      ? fromQuery.trim().toUpperCase()
      : undefined;

  // Header present but blank -> 400, even if ?tenant= is valid (variant A).
  if (hasHeader && headerCode === undefined) {
    throw new BadRequestException({
      statusCode: 400,
      code: 'TENANT_INVALID',
      message: 'X-Tenant header is present but blank',
    });
  }

  // Both declared and disagree (after normalization).
  if (
    headerCode !== undefined &&
    queryCode !== undefined &&
    headerCode !== queryCode
  ) {
    throw new BadRequestException({
      statusCode: 400,
      code: 'TENANT_CONFLICT',
      message: 'X-Tenant and ?tenant disagree',
    });
  }

  return headerCode ?? queryCode;
}
