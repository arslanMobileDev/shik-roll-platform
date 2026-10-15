/**
 * Courier auth configuration (env-driven, read once at module load —
 * same convention as the auth module).
 *
 *   COURIER_TOKEN_TTL_SECONDS  courier access token lifetime, default 12 hours
 *                              (one work shift; the courier re-authenticates
 *                              with the PIN when it expires)
 *   PIN_BCRYPT_ROUNDS          bcrypt cost factor for courier PIN hashing,
 *                              default 10
 *   COURIER_LOCATION_MAX_CLOCK_SKEW_MS
 *                              max |now - capturedAt| accepted by
 *                              POST /couriers/location, default 5 minutes
 *   COURIER_LOCATION_MIN_INTERVAL_MS
 *                              per-courier rate limit for location reports,
 *                              default 5 seconds
 */
export const COURIER_TOKEN_TTL_SECONDS = Number(
  process.env.COURIER_TOKEN_TTL_SECONDS ?? 12 * 60 * 60,
);

export const PIN_BCRYPT_ROUNDS = Number(process.env.PIN_BCRYPT_ROUNDS ?? 10);

export const COURIER_LOCATION_MAX_CLOCK_SKEW_MS = Number(
  process.env.COURIER_LOCATION_MAX_CLOCK_SKEW_MS ?? 5 * 60 * 1000,
);

export const COURIER_LOCATION_MIN_INTERVAL_MS = Number(
  process.env.COURIER_LOCATION_MIN_INTERVAL_MS ?? 5 * 1000,
);

/**
 * How long a self-deleted courier account can be brought back by
 * POST /couriers/auth/restore. Not environment tuning, same reasoning as
 * PHONE_RELEASE_WINDOW_DAYS on the customer side: the owner promises one
 * window, and dev/test/production must not drift on it. Tests backdate a
 * deletion instead of shortening the window.
 */
export const COURIER_RESTORE_WINDOW_DAYS = 7;

/**
 * Written over a self-deleted courier's name once the 7-day restore window
 * closes. A placeholder is needed at all because the row survives deletion (see
 * the courier_account_deletion migration) while `name` is NOT NULL. Product
 * copy, not tuning — the owner reads it in the staff courier list — so it is a
 * constant, not an env var, and dev and production cannot drift.
 *
 * Nothing writes it yet: deleteOwnAccount keeps the real name while a restore
 * can still use it, and the expiry job that overwrites it does not exist. Until
 * that job lands, a deleted courier's data is retained indefinitely.
 */
export const DELETED_COURIER_NAME = 'Удалённый курьер';
