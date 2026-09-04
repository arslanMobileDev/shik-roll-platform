/**
 * Auth bounded context configuration (env-driven, read once at module load —
 * same convention as the queues module).
 *
 *   JWT_SECRET               HMAC secret for access/refresh tokens (required in prod)
 *   JWT_ACCESS_TTL_SECONDS   access token lifetime, default 30 days
 *   JWT_REFRESH_TTL_SECONDS  refresh token lifetime, default 90 days
 *   OTP_TTL_SECONDS          OTP lifetime, default 180 (3 minutes)
 *   SMS_PROVIDER             when unset (dev/test), the OTP is the fixed '1234'
 *                            and is logged to the console instead of being sent
 */
export const JWT_SECRET = process.env.JWT_SECRET ?? 'shik-dev-jwt-secret';

export const ACCESS_TOKEN_TTL_SECONDS = Number(
  process.env.JWT_ACCESS_TTL_SECONDS ?? 30 * 24 * 60 * 60,
);

export const REFRESH_TOKEN_TTL_SECONDS = Number(
  process.env.JWT_REFRESH_TTL_SECONDS ?? 90 * 24 * 60 * 60,
);

export const OTP_TTL_SECONDS = Number(process.env.OTP_TTL_SECONDS ?? 180);

/** Fixed OTP used in dev/test when no SMS provider is configured. */
export const DEV_OTP_CODE = '1234';
