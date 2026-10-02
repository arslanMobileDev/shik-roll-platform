/**
 * Tenant resolved for the current request (ADR-1622).
 *
 * `code` is the slug the client sent (SHIK_ROLL) — the header carries a code,
 * never the UUID, because the UUID is minted per database by the backfill
 * migration and is not the same in dev, test and prod.
 */
export interface TenantContext {
  id: string;
  code: string;
}

/**
 * Prisma filter for "the tenant owning this row is usable" — ACTIVE and not
 * soft-deleted. Two consumers, one policy:
 *
 * - a relation filter (`tenant: ACTIVE_TENANT_FILTER`) in the PIN login
 *   lookups and in the JWT guards. The database does the work, so both read as
 *   an ordinary "no such row" and answer their existing uniform 401 — nothing
 *   in the response tells an unauthenticated caller that a tenant exists but is
 *   suspended.
 * - that is the row-side twin of TenantMiddleware's resolve(), which answers
 *   the same question about a *declared* tenant with 403/404 instead, because
 *   there the caller named the tenant and the distinction is actionable.
 *
 * The filter also drops the row whose tenant is deleted, so a soft-deleted
 * tenant is indistinguishable from a suspended one from the outside.
 */
export const ACTIVE_TENANT_FILTER = { status: 'ACTIVE', deletedAt: null };

/**
 * Minimal request shape used by TenantMiddleware and @CurrentTenant (avoids
 * express type coupling, same convention as RequestWithStaff/RequestWithCourier).
 *
 * `tenant` is absent when the client declared no tenant. That is legitimate:
 * every route is already scoped by a verified guard claim, and the public ones
 * (catalog, health, payment webhooks) must keep answering.
 */
export interface RequestWithTenant {
  headers: Record<string, string | string[] | undefined>;
  query?: Record<string, unknown>;
  tenant?: TenantContext;
}
