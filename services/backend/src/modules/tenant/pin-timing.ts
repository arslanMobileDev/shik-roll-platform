import * as bcrypt from 'bcryptjs';
import { PIN_BCRYPT_ROUNDS as STAFF_BCRYPT_ROUNDS } from '../staff/staff.config';
import { PIN_BCRYPT_ROUNDS as COURIER_BCRYPT_ROUNDS } from '../couriers/couriers.config';

/**
 * The most expensive hash a PIN row can hold, and therefore the cost of the
 * dummy: a dummy *cheaper* than the real hash is precisely the channel this
 * file closes — a missing account answered in 69 ms while a cost-12 row took
 * 281 ms (measured; bcrypt cost is 2^n, so 12 is 4x the work of 10).
 *
 * Read, not assumed. Two call sites write a literal 12 — cooks.service.ts and
 * staff-couriers.controller.ts — and the two env-driven configs below default
 * to 10 but accept a higher PIN_BCRYPT_ROUNDS, so a hardcoded ceiling would
 * silently undercut an operator who raised it.
 *
 * ponytail: a cost-10 row still answers faster than a missing one (the writers
 * disagree, and old rows keep their cost until rehashed) — the inversion is
 * what remains until every writer hashes at one cost.
 */
const HARDCODED_ROUNDS = 12;
const DUMMY_ROUNDS = Math.max(
  HARDCODED_ROUNDS,
  STAFF_BCRYPT_ROUNDS,
  COURIER_BCRYPT_ROUNDS,
);
const DUMMY_PIN = 'never-matches-any-real-pin';

// Eager, not lazy: bcrypt.hash is pure CPU over a constant string, so it has no
// realistic failure mode, and computing it at module load means the very first
// null-row login already pays the same single bcrypt.compare as every other
// branch (audit of 3be4a17, Q1). The catch only exists so a theoretical
// rejection cannot surface as an unhandledRejection while the promise is still
// unconsumed; awaiting it below still raises the real error.
const dummyHashPromise: Promise<string> = bcrypt.hash(DUMMY_PIN, DUMMY_ROUNDS);
dummyHashPromise.catch(() => undefined);

/**
 * Compare a submitted PIN against a bcrypt hash, always paying the bcrypt
 * cost even when the row or its hash is missing.
 *
 * Without this, a login against an unknown phone / terminal code returns
 * measurably faster than one against a known account with the wrong PIN,
 * leaking whether the account exists. The caller answers the same 401 in
 * both cases; this helper flattens the timing.
 *
 * `pinHash` may be null or undefined; the bcrypt comparison still runs
 * against a dummy hash and returns false, so the caller can collapse the
 * "row missing" and "PIN wrong" branches into one.
 *
 * A row that does have a hash is compared against that very hash, so its cost
 * is matched by construction — no second dummy, and no `bcrypt.getRounds`
 * bookkeeping, is needed for the present-hash branch. The cost only has to be
 * chosen for the dummy, and there it is the ceiling (above).
 *
 * ADR-1622 step 4, C3; review of 3be4a17.
 */
export async function constantTimePinCheck(
  pin: string,
  pinHash: string | null | undefined,
): Promise<boolean> {
  const hash = pinHash ?? (await dummyHashPromise);
  const ok = await bcrypt.compare(pin, hash);
  return ok && pinHash != null;
}
