import * as bcrypt from 'bcryptjs';

const DUMMY_ROUNDS = 10;

let dummyHashPromise: Promise<string> | null = null;

function getDummyHash(): Promise<string> {
  if (!dummyHashPromise) {
    dummyHashPromise = bcrypt.hash('never-matches-any-real-pin', DUMMY_ROUNDS);
  }
  return dummyHashPromise;
}

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
  const hash = pinHash ?? (await getDummyHash());
  const ok = await bcrypt.compare(pin, hash);
  return ok && pinHash != null;
}
