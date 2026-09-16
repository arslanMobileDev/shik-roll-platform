import { Prisma, StaffRole } from '@prisma/client';
import { AnalyticsService, revenueRange } from './analytics.service';
import { RevenuePeriod } from './dto/analytics-query.dto';
import { AuthenticatedStaff } from '../staff/staff.types';
const staff: AuthenticatedStaff = { id: 'staff', phone: '+79990000000', role: StaffRole.OWNER, brandId: '11111111-1111-4111-8111-111111111111' };
const D = (n: string) => new Prisma.Decimal(n);

describe('AnalyticsService', () => {
  let db: any;
  let service: AnalyticsService;
  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-09-16T10:00:00Z'));
    db = { $queryRaw: jest.fn().mockResolvedValue([]), branch: { findFirst: jest.fn().mockResolvedValue({ id: 'branch' }), findMany: jest.fn().mockResolvedValue([]) },
      orderItem: { groupBy: jest.fn().mockResolvedValue([]), findFirst: jest.fn().mockResolvedValue({ name: 'Роллы' }) },
      order: { groupBy: jest.fn().mockResolvedValue([]) },
    };
    db.$transaction = jest.fn(cb => cb(db));
    service = new AnalyticsService(db);
  });
  afterEach(() => jest.useRealTimers());

  it('today sums completed revenue and rounds average without float arithmetic', async () => {
    db.$queryRaw.mockResolvedValue([{ date: '2026-09-16', total: D('1000.01'), count: 3n }]);
    const result = await service.revenue(staff, {});
    expect(result.summary).toEqual({ total: 1000.01, ordersCount: 3, averageCheck: 333.34 });
    expect(result.period.from).toBe('2026-09-15T21:00:00.000Z');
    expect(result.period.to).toBe('2026-09-16T20:59:59.999Z');
    const query = db.$queryRaw.mock.calls[0][0];
    expect(query.sql).toContain("status = 'COMPLETED'");
    expect(query.sql).toContain('deleted_at IS NULL');
    expect(query.sql).toContain('completed_at >=');
    expect(query.sql).not.toContain('created_at');
    expect(query.values).toContain(staff.brandId);
    expect(db.$transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'RepeatableRead' });
  });

  it('month has every calendar day including empty days', async () => {
    db.$queryRaw.mockResolvedValue([{ date: '2026-09-02', total: D('500'), count: 2n }]);
    const result = await service.revenue(staff, { period: RevenuePeriod.MONTH });
    expect(result.byDay).toHaveLength(30);
    expect(result.byDay[0]).toEqual({ date: '2026-09-01', total: 0, count: 0 });
    expect(result.byDay[1]).toEqual({ date: '2026-09-02', total: 500, count: 2 });
  });

  it('empty period returns zeroes', async () => {
    const result = await service.revenue(staff, {});
    expect(result.summary).toEqual({ total: 0, ordersCount: 0, averageCheck: 0 });
    expect(result.byDay).toHaveLength(1);
    expect(result.topItems).toEqual([]);
    expect(result.byBranch).toEqual([]);
  });

  it('scopes all queries to the actor brand and optional branch', async () => {
    const branchId = '22222222-2222-4222-8222-222222222222';
    await service.revenue(staff, { branchId });
    expect(db.branch.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: branchId, deletedAt: null, brandBranches: { some: { brandId: staff.brandId } } } }));
    expect(db.$queryRaw.mock.calls[0][0].values).toContain(branchId);
    expect(db.orderItem.groupBy.mock.calls[0][0].where.order).toMatchObject({ brandId: staff.brandId, branchId, status: 'COMPLETED', deletedAt: null });
    expect(db.order.groupBy).not.toHaveBeenCalled();
  });

  it('rejects a foreign branch before revenue queries', async () => {
    db.branch.findFirst.mockResolvedValue(null);
    await expect(service.revenue(staff, { branchId: 'foreign' })).rejects.toMatchObject({ response: { code: 'BRANCH_NOT_FOUND' } });
    expect(db.$queryRaw).not.toHaveBeenCalled();
  });

  it.each([undefined, 'branch'])('denies manager without a verified branch assignment (%s)', async branchId => {
    await expect(service.revenue({ ...staff, role: StaffRole.MANAGER }, { branchId })).rejects.toMatchObject({ status: 403 });
    expect(db.$transaction).not.toHaveBeenCalled();
  });

  it('groups top items by ID and uses snapshot names; includes brand branch breakdown', async () => {
    db.orderItem.groupBy.mockResolvedValue([{ menuItemId: 'item', _sum: { quantity: 5, totalAmount: D('750.50') } }]);
    db.order.groupBy.mockResolvedValue([{ branchId: 'b', _sum: { totalAmount: D('700.50') }, _count: { _all: 2 } }]);
    db.branch.findMany.mockResolvedValue([{ id: 'b', name: 'Центр' }]);
    const result = await service.revenue(staff, {});
    expect(result.topItems).toEqual([{ menuItemId: 'item', name: 'Роллы', quantity: 5, revenue: 750.5 }]);
    expect(result.byBranch).toEqual([{ branchId: 'b', branchName: 'Центр', total: 700.5, count: 2 }]);
    expect(db.orderItem.groupBy.mock.calls[0][0]).toMatchObject({ by: ['menuItemId'], take: 5 });
  });
});

describe('MSK calendar periods', () => {
  it('changes day at 21:00 UTC', () => {
    const range = revenueRange({}, new Date('2026-09-15T21:00:00Z'));
    expect(range.days).toEqual(['2026-09-16']);
  });
  it('week runs Monday through Sunday across year boundary', () => {
    const range = revenueRange({ period: RevenuePeriod.WEEK }, new Date('2027-01-01T10:00:00Z'));
    expect(range.days[0]).toBe('2026-12-28');
    expect(range.days.at(-1)).toBe('2027-01-03');
  });
  it('includes leap day and all of yesterday', () => {
    expect(revenueRange({ period: RevenuePeriod.YEAR }, new Date('2024-03-01')).days).toHaveLength(366);
    expect(revenueRange({ period: RevenuePeriod.YESTERDAY }, new Date('2024-03-01T01:00:00Z')).days).toEqual(['2024-02-29']);
  });
  it.each([
    { period: RevenuePeriod.CUSTOM },
    { period: RevenuePeriod.CUSTOM, dateFrom: '2026-02-30', dateTo: '2026-03-01' },
    { period: RevenuePeriod.CUSTOM, dateFrom: '2026-09-20', dateTo: '2026-09-19' },
    { dateFrom: '2026-09-01' },
  ])('rejects invalid custom dates %j', query => expect(() => revenueRange(query)).toThrow());
});
