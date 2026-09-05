/**
 * Auth bounded context configuration (env-driven, read once at module load —
 * same convention as the queues module).
 *
 *   JWT_SECRET               HMAC secret for access/refresh tokens (required in prod)
 *   JWT_ACCESS_TTL_SECONDS   access token lifetime, default 30 days
 *   JWT_REFRESH_TTL_SECONDS  refresh token lifetime, default 90 days
 *   OTP_TTL_SECONDS          OTP lifetime, default 300 (5 minutes)
 *   OTP_SEND_COOLDOWN_SECONDS  min interval between OTP sends per phone, default 60
 *   OTP_MAX_ATTEMPTS         max verify attempts per issued code, default 5
 *   DEV_OTP                  when 'true', forces the fixed dev code even in production
 *   SMS_PROVIDER             SMS gateway identifier; required in production to
 *                            actually deliver codes (integration is future work)
 *
 * Dev fallback: when NODE_ENV !== 'production' OR DEV_OTP === 'true', the OTP is
 * the fixed code '1111' — logged and returned in the response, never sent via SMS.
 * In production the code is random and is never written to logs (152-FZ hygiene:
 * no plaintext OTP / phone data in production logs).
 */
export const JWT_SECRET = process.env.JWT_SECRET ?? 'shik-dev-jwt-secret';

export const ACCESS_TOKEN_TTL_SECONDS = Number(
  process.env.JWT_ACCESS_TTL_SECONDS ?? 30 * 24 * 60 * 60,
);

export const REFRESH_TOKEN_TTL_SECONDS = Number(
  process.env.JWT_REFRESH_TTL_SECONDS ?? 90 * 24 * 60 * 60,
);

export const OTP_TTL_SECONDS = Number(process.env.OTP_TTL_SECONDS ?? 300);

export const OTP_SEND_COOLDOWN_SECONDS = Number(
  process.env.OTP_SEND_COOLDOWN_SECONDS ?? 60,
);

export const OTP_MAX_ATTEMPTS = Number(process.env.OTP_MAX_ATTEMPTS ?? 5);

/** Fixed OTP used in dev/test (non-production NODE_ENV or DEV_OTP=true). */
export const DEV_OTP_CODE = '1111';

/**
 * Dev OTP mode: non-production environments, or an explicit DEV_OTP=true flag
 * (e.g. a production smoke-test window). In this mode no SMS is sent and the
 * fixed code '1111' is used.
 */
export function isDevOtpMode(): boolean {
  return process.env.NODE_ENV !== 'production' || process.env.DEV_OTP === 'true';
}
