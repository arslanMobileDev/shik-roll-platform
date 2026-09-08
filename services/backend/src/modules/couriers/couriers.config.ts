/**
 * Courier auth configuration (env-driven, read once at module load —
 * same convention as the auth module).
 *
 *   COURIER_TOKEN_TTL_SECONDS  courier access token lifetime, default 12 hours
 *                              (one work shift; the courier re-authenticates
 *                              with the PIN when it expires)
 *   PIN_BCRYPT_ROUNDS          bcrypt cost factor for courier PIN hashing,
 *                              default 10
 */
export const COURIER_TOKEN_TTL_SECONDS = Number(
  process.env.COURIER_TOKEN_TTL_SECONDS ?? 12 * 60 * 60,
);

export const PIN_BCRYPT_ROUNDS = Number(process.env.PIN_BCRYPT_ROUNDS ?? 10);
