import { HttpStatus } from '@nestjs/common';
import {
  __pinRateLimitResetForTests,
  pinRateLimitConsume,
  pinRateLimitReset,
  TooManyAttemptsException,
} from './pin-rate-limit';

const WINDOW_MS = 900_000;
const MAX = 5;

const consume = (tenant: string | undefined, key: string) =>
  pinRateLimitConsume(tenant, key);

/** Runs `n` attempts that are expected to pass, so a throw fails the test. */
const consumeWithinBudget = (n: number, tenant: string | undefined, key: string) => {
  for (let i = 0; i < n; i += 1) consume(tenant, key);
};

const catchTooMany = (tenant: string | undefined, key: string) => {
  try {
    consume(tenant, key);
  } catch (error) {
    return error;
  }
  throw new Error('expected pinRateLimitConsume to throw');
};

describe('pin-rate-limit', () => {
  beforeEach(() => {
    __pinRateLimitResetForTests();
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('lets the budget through and answers the attempt after it with 429', () => {
    consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001');

    const error = catchTooMany('SHIK_ROLL', '+79990000001');

    expect(error).toBeInstanceOf(TooManyAttemptsException);
    expect((error as TooManyAttemptsException).getStatus()).toBe(
      HttpStatus.TOO_MANY_REQUESTS,
    );
    expect((error as TooManyAttemptsException).getResponse()).toMatchObject({
      statusCode: 429,
      code: 'TOO_MANY_ATTEMPTS',
    });
  });

  it('reports the seconds left in the window on the 429', () => {
    consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001');
    jest.setSystemTime(new Date('2026-01-01T00:05:00.000Z'));

    const error = catchTooMany('SHIK_ROLL', '+79990000001') as TooManyAttemptsException;

    // 15-minute window, 5 spent: 10 minutes to go.
    expect(error.retryAfterSeconds).toBe(600);
  });

  it('keeps one key out of another key’s budget', () => {
    consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001');

    // A different account still has its whole budget.
    expect(() =>
      consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000002'),
    ).not.toThrow();
  });

  it('keeps one tenant out of another tenant’s budget', () => {
    consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001');

    expect(() => consume('TENANT_B', '+79990000001')).not.toThrow();
  });

  it('counts a declaration-less client under the default bucket', () => {
    consumeWithinBudget(MAX, undefined, '+79990000001');

    expect(() => consume(undefined, '+79990000001')).toThrow(
      TooManyAttemptsException,
    );
    // ...and does not touch the bucket of a client that did declare one.
    expect(() => consume('SHIK_ROLL', '+79990000001')).not.toThrow();
  });

  it('resets the budget on a successful login', () => {
    consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001');
    pinRateLimitReset('SHIK_ROLL', '+79990000001');

    expect(() =>
      consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001'),
    ).not.toThrow();
  });

  it('lets the key in again once the window has passed', () => {
    consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001');
    jest.setSystemTime(new Date(Date.now() + WINDOW_MS + 1));

    // The fresh window starts from zero, not from the old count: the whole
    // budget is available again.
    expect(() =>
      consumeWithinBudget(MAX, 'SHIK_ROLL', '+79990000001'),
    ).not.toThrow();
  });
});
