import { PrismaService } from '../../prisma/prisma.service';
import { OrdersRepository } from './orders.repository';

const BRANCH_ID = '22222222-2222-2222-2222-222222222222';
const ALLOCATION_DAY = new Date(Date.UTC(2026, 7, 30));

function makeRepository(lastValue = 1) {
  const prisma = {
    $queryRaw: jest.fn().mockResolvedValue([{ last_value: lastValue }]),
    order: { count: jest.fn() },
  };
  return {
    prisma,
    repository: new OrdersRepository(prisma as unknown as PrismaService),
  };
}

/** Statement text and bound values of the single allocation query. */
function allocationQuery(prisma: { $queryRaw: jest.Mock }) {
  const [strings, ...values] = prisma.$queryRaw.mock.calls[0];
  return { sql: (strings as string[]).join('?'), values: values as unknown[] };
}

describe('OrdersRepository.nextOrderSequence', () => {
  it('allocates with one atomic upsert instead of counting orders (AC-4)', async () => {
    const { prisma, repository } = makeRepository();

    await repository.nextOrderSequence(
      BRANCH_ID,
      new Date('2026-08-30T10:00:00.000Z'),
    );

    const { sql } = allocationQuery(prisma);
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
    expect(sql).toContain('INSERT INTO "order_sequences"');
    expect(sql).toContain('ON CONFLICT ("branch_id", "day")');
    expect(sql).toContain('"last_value" = "order_sequences"."last_value" + 1');
    expect(sql).toContain('RETURNING "last_value"');
    // Allocation state is read and incremented; orders are never counted.
    expect(sql).not.toContain('COUNT');
    expect(prisma.order.count).not.toHaveBeenCalled();
  });

  it('seeds at 1 and returns the stored value unchanged, so the first order is 0001', async () => {
    const seeded = makeRepository(1);
    const stored = makeRepository(7);

    const first = await seeded.repository.nextOrderSequence(
      BRANCH_ID,
      ALLOCATION_DAY,
    );
    const later = await stored.repository.nextOrderSequence(
      BRANCH_ID,
      ALLOCATION_DAY,
    );

    // 1-based: the row is inserted at 1, never at 0.
    expect(allocationQuery(seeded.prisma).sql).toContain(', 1, now())');
    expect(first.sequence).toBe(1);
    // No offset is applied to the value the statement returned.
    expect(later.sequence).toBe(7);
  });

  it('returns the UTC day of allocation and binds it as a date string (B-1)', async () => {
    const { prisma, repository } = makeRepository();

    // 23:30 UTC: already the next day in a positive-offset session (Moscow)
    // and still the previous day in a negative-offset one (New York).
    const { day } = await repository.nextOrderSequence(
      BRANCH_ID,
      new Date('2026-08-30T23:30:00.000Z'),
    );

    expect(day.toISOString()).toBe('2026-08-30T00:00:00.000Z');
    const { values } = allocationQuery(prisma);
    // A bound JS Date is cast by Postgres in the session timezone; the string
    // is cast as a bare date and cannot shift onto the previous day.
    expect(typeof values[1]).toBe('string');
    expect(values).toEqual([BRANCH_ID, '2026-08-30']);
  });
});
