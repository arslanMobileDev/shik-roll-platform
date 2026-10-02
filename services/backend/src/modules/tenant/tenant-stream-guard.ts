import { defer, EMPTY, interval, Observable } from 'rxjs';
import { catchError, filter, switchMap, take } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Notifier that ends a tenant's SSE stream once its tenant stops being ACTIVE
 * (ADR-1622 step 4, C5).
 *
 * A stream lives until the client disconnects, so a tenant suspended in the
 * database would otherwise keep receiving live order events. This re-reads the
 * authoritative tenant row on a fixed cadence and emits once; `takeUntil` turns
 * that single emission into a graceful `complete()` — the client sees EOF,
 * EventSource reconnects, and the guard answers 403, matching the HTTP-level
 * answer from TenantMiddleware.resolve. The flow just ends: no reason, no
 * tenant details, nothing that says whether the tenant exists.
 *
 * A fixed cadence also means silence cannot hide a suspension: with no orders
 * moving, the stream still closes within one tick.
 *
 * ponytail: one indexed PK read per open stream per tick. Fine at MVP board
 * counts; batch the checks if a tenant ever holds hundreds of streams.
 */
export function tenantActiveGuard$(
  prisma: PrismaService,
  tenantId: string,
  cadenceMs: number,
): Observable<unknown> {
  return interval(cadenceMs).pipe(
    switchMap(() =>
      // defer, so a failure to even start the read is caught below too.
      defer(() =>
        prisma.tenant.findUnique({
          where: { id: tenantId },
          select: { status: true, deletedAt: true },
        }),
      ).pipe(
        // A transient read failure must not kill a live board: skip this tick
        // and ask again on the next one. The stream stays open, not wrong.
        catchError(() => EMPTY),
      ),
    ),
    filter(
      (tenant) =>
        !tenant || tenant.status !== 'ACTIVE' || tenant.deletedAt !== null,
    ),
    take(1),
  );
}
