import * as bcrypt from 'bcryptjs';

const DUMMY_ROUNDS = 10;
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
 * ADR-1622 step 4, C3.
 */
export async function constantTimePinCheck(
  pin: string,
  pinHash: string | null | undefined,
): Promise<boolean> {
  const hash = pinHash ?? (await dummyHashPromise);
  const ok = await bcrypt.compare(pin, hash);
  return ok && pinHash != null;
}
