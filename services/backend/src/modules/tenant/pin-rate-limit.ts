import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';

/**
 * Per-key rate limit for the four PIN logins (ADR-1622 step 4, C4).
 *
 * Every attempt is counted, successful or not, and the 429 is answered before
 * the account is looked up — so an unknown phone burns a slot exactly like a
 * known one. Counting only failures would make the limiter itself the
 * enumeration oracle the uniform 401 exists to prevent.
 *
 * ponytail: a module-level Map, the same shape as couriers.lastLocationAt —
 * fixed window, no eviction, exact while there is one replica, and one leaked
 * entry per attacked key. Replace with Redis (INCR + EXPIRE on the same key)
 * when tenant #2 or a second replica appears; go sliding-window only if a
 * caller ever needs smoother than 5-per-15-minutes.
 */
const maxAttempts = Number(process.env.PIN_RATE_LIMIT_MAX) || 5;
const windowMs = Number(process.env.PIN_RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000;

interface Bucket {
  count: number;
  windowStart: number;
}

const buckets = new Map<string, Bucket>();

/**
 * 429 carrying the seconds left in the window. Nest puts no headers on an
 * HttpException, so the value rides on the exception for the filter below.
 */
export class TooManyAttemptsException extends HttpException {
  constructor(readonly retryAfterSeconds: number) {
    super(
      {
        statusCode: HttpStatus.TOO_MANY_REQUESTS,
        code: 'TOO_MANY_ATTEMPTS',
        message: 'Too many attempts, try again later',
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}

/**
 * Counts one attempt for (tenant, key) and throws once the budget is gone.
 *
 * `tenantCode` is the code the client declared, not the tenant id: it is what
 * the middleware validated, and it is stable across databases (the id is minted
 * per database). A caller with no tenant declaration — the legacy header-less
 * clients — shares the `default` bucket for that key, the strictest reading.
 */
export function pinRateLimitConsume(
  tenantCode: string | undefined,
  key: string,
): void {
  const id = `${tenantCode ?? 'default'}:${key}`;
  const now = Date.now();
  const bucket = buckets.get(id);

  if (!bucket || now - bucket.windowStart >= windowMs) {
    buckets.set(id, { count: 1, windowStart: now });
    return;
  }

  bucket.count += 1;
  if (bucket.count > maxAttempts) {
    throw new TooManyAttemptsException(
      Math.ceil((bucket.windowStart + windowMs - now) / 1000),
    );
  }
}

/**
 * Clears the key on a successful login. The budget is for guessing, not for
 * ordinary use: someone who signs in every morning must never accumulate.
 */
export function pinRateLimitReset(
  tenantCode: string | undefined,
  key: string,
): void {
  buckets.delete(`${tenantCode ?? 'default'}:${key}`);
}

/** The Map outlives a spec's beforeEach, unlike the app it guards. */
export function __pinRateLimitResetForTests(): void {
  buckets.clear();
}

/** Puts Retry-After on the 429 — the one thing an HttpException cannot carry. */
@Catch(TooManyAttemptsException)
export class TooManyAttemptsFilter implements ExceptionFilter {
  catch(exception: TooManyAttemptsException, host: ArgumentsHost): void {
    // Minimal response shape, same convention as RequestWithTenant: no express
    // type coupling just to call two methods.
    const response = host.switchToHttp().getResponse<{
      setHeader(name: string, value: string): void;
      status(code: number): { json(body: unknown): void };
    }>();

    response.setHeader('Retry-After', String(exception.retryAfterSeconds));
    response
      .status(HttpStatus.TOO_MANY_REQUESTS)
      .json(exception.getResponse());
  }
}
