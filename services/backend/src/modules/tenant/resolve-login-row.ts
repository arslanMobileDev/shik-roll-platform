import { ConflictException } from '@nestjs/common';
import { TenantContext } from './tenant.types';

/**
 * Resolves the row a PIN login is checked against (ADR-1622 step 4b).
 *
 * Login keys — staff/courier phone, kitchen terminal code — are unique per
 * tenant since migration 20261002111555, not globally. The tenant is the one
 * the client declared (X-Tenant / ?tenant=), or, for the clients that predate
 * the header, the only tenant owning the key.
 *
 * Returns the row, or null when the key is unknown — callers answer their
 * existing uniform 401, so nothing here distinguishes "no such account" from
 * "wrong tenant". Throws 409 AMBIGUOUS_TENANT when several tenants own the key:
 * the answer is not knowable, and the client must start sending X-Tenant.
 *
 * `lookupByKey` contract: filter by ACTIVE_TENANT_FILTER and pass `take: 2` —
 * only "none / one / more than one" is ever asked of it, and it must not
 * answer with a row whose tenant is suspended or deleted.
 *
 * ponytail: the "several" branch trusts the (tenant_id, key) UNIQUE — at most
 * one row per tenant, so two rows mean two tenants, which saves the second
 * query. If that invariant ever stops holding, switch to `distinct: ['tenantId']`
 * and accept the extra round trip.
 */
export async function resolveLoginRow<T>(
  declared: TenantContext | undefined,
  lookupByKey: () => Promise<T[]>,
  lookupScoped: (tenantId: string) => Promise<T | null>,
): Promise<T | null> {
  if (declared) {
    return lookupScoped(declared.id);
  }

  const rows = await lookupByKey();
  if (rows.length > 1) {
    // Accepted risk (ADR-1622 step 4b, confirmed 2026-10-02): this answers
    // before the PIN is checked, so it confirms the key exists in more than one
    // tenant. Unavoidable — the PIN cannot be verified without first knowing
    // which row to verify it against. With a single tenant the branch is
    // unreachable; revisit if the header ever becomes mandatory.
    throw new ConflictException({
      statusCode: 409,
      code: 'AMBIGUOUS_TENANT',
      message:
        'This login exists in several tenants; send the X-Tenant header to pick one',
    });
  }
  return rows[0] ?? null;
}
