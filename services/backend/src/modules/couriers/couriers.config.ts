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
