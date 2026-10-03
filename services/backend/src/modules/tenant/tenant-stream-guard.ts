import { Logger } from '@nestjs/common';
import { defer, interval, Observable, of } from 'rxjs';
import {
  catchError,
  exhaustMap,
  filter,
  map,
  scan,
  take,
  timeout,
} from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * How long one tenant read may take before it is written off. Without it
 * `exhaustMap` would wait forever: a read that never settles would block every
 * later tick, so the guard would stop checking and the stream would stay open
 * against a suspended tenant for good.
 */
const CHECK_TIMEOUT_MS = 5_000;

/**
 * Consecutive ticks that failed to confirm ACTIVE before the stream is closed.
 * One is a blip (a reconnect on every hiccup would flap live boards); three in
 * a row means the database — not the network — cannot verify the tenant, and an
 * unverifiable stream is exactly what C5 exists to disallow.
 */
const MAX_UNCONFIRMED_TICKS = 3;

const logger = new Logger('TenantStreamGuard');

interface Tick {
  /** The read came back, healthy or not. */
  confirmed: boolean;
  /** The read says the tenant must not hold a stream any more. */
  closes: boolean;
}

interface GuardState {
  unconfirmed: number;
  closes: boolean;
}

/** No row, or a row that is not ACTIVE-and-not-deleted. */
function isUnhealthy(
  tenant: { status: string; deletedAt: Date | null } | null,
): boolean {
  return !tenant || tenant.status !== 'ACTIVE' || tenant.deletedAt !== null;
}

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
 * `exhaustMap`, not `switchMap` (review of 64ed203): switchMap tore down the
 * in-flight read as soon as the next tick arrived, so a read slower than the
 * cadence could be cancelled on every tick and its SUSPENDED answer never
 * reached the filter — the stream outlived the tenant it was guarding. Skipping
 * a tick is fine; losing an answer is not, and the timeout above keeps the
 * "skip" from ever becoming "stop checking".
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
    exhaustMap(() =>
      // defer, so a failure to even start the read is caught below too.
      defer(() =>
        prisma.tenant.findUnique({
          where: { id: tenantId },
          select: { status: true, deletedAt: true },
        }),
      ).pipe(
        timeout(CHECK_TIMEOUT_MS),
        map((tenant): Tick => ({ confirmed: true, closes: isUnhealthy(tenant) })),
        // A failed or timed-out read is not "the tenant is fine": it is a tick
        // that confirmed nothing. Counting it — rather than swallowing it with
        // EMPTY — is what lets MAX_UNCONFIRMED_TICKS close a stream whose
        // tenant can no longer be verified at all.
        catchError((error: Error) => {
          logger.warn(
            `Tenant ${tenantId} status check failed: ${error.message}`,
          );
          return of<Tick>({ confirmed: false, closes: false });
        }),
      ),
    ),
    scan<Tick, GuardState>(
      (state, tick) => ({
        unconfirmed: tick.confirmed ? 0 : state.unconfirmed + 1,
        closes: tick.closes,
      }),
      { unconfirmed: 0, closes: false },
    ),
    filter(
      (state) => state.closes || state.unconfirmed >= MAX_UNCONFIRMED_TICKS,
    ),
    take(1),
  );
}
