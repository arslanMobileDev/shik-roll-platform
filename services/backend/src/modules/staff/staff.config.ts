/**
 * Staff (back-office) auth configuration, read once at module load —
 * same convention as couriers/kitchen.
 *
 *   STAFF_TOKEN_TTL_SECONDS  staff access token lifetime, default 12h
 *   PIN_BCRYPT_ROUNDS        bcrypt cost for PIN hashing, default 10
 */
export const STAFF_TOKEN_TTL_SECONDS = Number(
  process.env.STAFF_TOKEN_TTL_SECONDS ?? 12 * 60 * 60,
);

export const PIN_BCRYPT_ROUNDS = Number(process.env.PIN_BCRYPT_ROUNDS ?? 10);
