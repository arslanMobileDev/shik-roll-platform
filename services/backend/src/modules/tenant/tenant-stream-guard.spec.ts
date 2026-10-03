import { Logger } from '@nestjs/common';
import { Subscription } from 'rxjs';
import { tenantActiveGuard$ } from './tenant-stream-guard';

const TENANT_ID = 'tenant-1';
const CADENCE_MS = 100;
const ACTIVE = { status: 'ACTIVE', deletedAt: null };
const SUSPENDED = { status: 'SUSPENDED', deletedAt: null };

/**
 * The guard as the two SSE streams use it: `takeUntil` only needs to know
 * whether it emitted, so every test asks "has it emitted yet?" rather than
 * inspecting a value.
 */
describe('tenantActiveGuard$', () => {
  let prisma: { tenant: { findUnique: jest.Mock } };
  let warn: jest.SpyInstance;
  let subscription: Subscription | undefined;

  beforeEach(() => {
    jest.useFakeTimers();
    prisma = { tenant: { findUnique: jest.fn() } };
    // A failing check must be visible in the log (it used to be swallowed);
    // silenced here so the suite output stays readable.
    warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
  });

  afterEach(() => {
    subscription?.unsubscribe();
    subscription = undefined;
    warn.mockRestore();
    jest.useRealTimers();
  });

  const open = () => {
    const emitted: unknown[] = [];
    let completed = false;
    subscription = tenantActiveGuard$(
      prisma as never,
      TENANT_ID,
      CADENCE_MS,
    ).subscribe({
      next: (value) => emitted.push(value),
      complete: () => {
        completed = true;
      },
    });
    return { emitted, isCompleted: () => completed };
  };

  it('reads the tenant row on the cadence and stays open while it is ACTIVE', async () => {
    prisma.tenant.findUnique.mockResolvedValue(ACTIVE);
    const guard = open();

    await jest.advanceTimersByTimeAsync(CADENCE_MS * 3);

    expect(prisma.tenant.findUnique).toHaveBeenCalledTimes(3);
    expect(prisma.tenant.findUnique).toHaveBeenCalledWith({
      where: { id: TENANT_ID },
      select: { status: true, deletedAt: true },
    });
    expect(guard.emitted).toEqual([]);
    expect(guard.isCompleted()).toBe(false);
  });

  it('closes within one tick of the tenant leaving ACTIVE', async () => {
    prisma.tenant.findUnique.mockResolvedValue(ACTIVE);
    const guard = open();
    await jest.advanceTimersByTimeAsync(CADENCE_MS);
    expect(guard.isCompleted()).toBe(false);

    prisma.tenant.findUnique.mockResolvedValue(SUSPENDED);
    await jest.advanceTimersByTimeAsync(CADENCE_MS);

    expect(guard.isCompleted()).toBe(true);
  });

  it('does not discard an in-flight check when the next tick arrives', async () => {
    // The switchMap failure (review of 64ed203): the read below is still in
    // flight when the second tick fires, and its answer is the one that matters.
    let answer!: (tenant: unknown) => void;
    prisma.tenant.findUnique.mockReturnValue(
      new Promise((resolve) => {
        answer = resolve;
      }),
    );
    const guard = open();

    await jest.advanceTimersByTimeAsync(CADENCE_MS);
    await jest.advanceTimersByTimeAsync(CADENCE_MS);

    // exhaustMap, not switchMap: the second tick was dropped rather than
    // tearing down the running read and starting another.
    expect(prisma.tenant.findUnique).toHaveBeenCalledTimes(1);

    answer(SUSPENDED);
    await jest.advanceTimersByTimeAsync(1);

    // ...and the answer of the check that was already running still lands.
    expect(guard.isCompleted()).toBe(true);
  });

  it('closes after three consecutive checks that could not be made at all', async () => {
    prisma.tenant.findUnique.mockRejectedValue(new Error('db is down'));
    const guard = open();

    await jest.advanceTimersByTimeAsync(CADENCE_MS * 2);
    // One blip must not drop a live board — the pre-existing guarantee.
    expect(guard.isCompleted()).toBe(false);

    await jest.advanceTimersByTimeAsync(CADENCE_MS);

    // Three in a row is not a blip: nothing can confirm the tenant, so the
    // stream may not stay open on an unverifiable tenant.
    expect(guard.isCompleted()).toBe(true);
    expect(warn).toHaveBeenCalled();
  });

  it('forgets earlier blips once a check confirms ACTIVE', async () => {
    prisma.tenant.findUnique
      .mockRejectedValueOnce(new Error('blip'))
      .mockRejectedValueOnce(new Error('blip'))
      .mockResolvedValueOnce(ACTIVE)
      .mockRejectedValue(new Error('blip'));
    const guard = open();

    await jest.advanceTimersByTimeAsync(CADENCE_MS * 5);

    // Two failures, a healthy read, then two more: the counter is "in a row",
    // not "in total", so the stream is still up.
    expect(guard.isCompleted()).toBe(false);
  });

  it('closes when a check never settles, instead of waiting on it forever', async () => {
    prisma.tenant.findUnique.mockReturnValue(new Promise(() => undefined));
    const guard = open();

    await jest.advanceTimersByTimeAsync(CADENCE_MS * 3);
    // Nothing has been confirmed, but no timeout has elapsed either: exhaustMap
    // is still waiting on the first read.
    expect(guard.isCompleted()).toBe(false);

    await jest.advanceTimersByTimeAsync(20_000);

    // Three timed-out checks, then done — a hanging database cannot pin the
    // connection open.
    expect(guard.isCompleted()).toBe(true);
  });
});
