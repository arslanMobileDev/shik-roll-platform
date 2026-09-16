import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { OrderStatus, Prisma, StaffRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthenticatedStaff } from '../staff/staff.types';
import { AnalyticsQueryDto, RevenuePeriod } from './dto/analytics-query.dto';
import { RevenueResponse } from './entities/revenue-response.entity';

const DAY = 86_400_000;
const MSK = 3 * 3_600_000;
const money = (value: Prisma.Decimal) => value.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP).toNumber();
const dateKey = (value: number) => new Date(value).toISOString().slice(0, 10);

export function revenueRange(query: AnalyticsQueryDto, now = new Date()) {
  const period = query.period ?? RevenuePeriod.TODAY;
  const today = new Date(now.getTime() + MSK);
  let start = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  let end = start + DAY;
  const labels: Record<RevenuePeriod, string> = {
    today: 'Сегодня', yesterday: 'Вчера', week: 'Неделя', month: 'Месяц', year: 'Год', custom: 'Период',
  };
  if (period !== RevenuePeriod.CUSTOM && (query.dateFrom !== undefined || query.dateTo !== undefined)) {
    throw new BadRequestException('Dates are only supported for period=custom');
  }
  if (period === RevenuePeriod.YESTERDAY) { start -= DAY; end -= DAY; }
  if (period === RevenuePeriod.WEEK) {
    start -= ((today.getUTCDay() + 6) % 7) * DAY; end = start + 7 * DAY;
  }
  if (period === RevenuePeriod.MONTH) {
    start = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 1);
    end = Date.UTC(today.getUTCFullYear(), today.getUTCMonth() + 1, 1);
  }
  if (period === RevenuePeriod.YEAR) {
    start = Date.UTC(today.getUTCFullYear(), 0, 1); end = Date.UTC(today.getUTCFullYear() + 1, 0, 1);
  }
  if (period === RevenuePeriod.CUSTOM) {
    const parse = (value?: string) => {
      if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new BadRequestException('Both custom dates must be YYYY-MM-DD');
      const stamp = Date.parse(`${value}T00:00:00.000Z`);
      if (!Number.isFinite(stamp) || dateKey(stamp) !== value || value < '2000-01-01') {
        throw new BadRequestException('Invalid calendar date (minimum 2000-01-01)');
      }
      return stamp;
    };
    start = parse(query.dateFrom); end = parse(query.dateTo) + DAY;
    if (end <= start || (end - start) / DAY > 3660) throw new BadRequestException('Custom period must contain 1 to 3660 days');
  }
  const days: string[] = [];
  for (let day = start; day < end; day += DAY) days.push(dateKey(day));
  return { from: new Date(start - MSK), end: new Date(end - MSK), days,
    label: period === RevenuePeriod.CUSTOM ? `${query.dateFrom} — ${query.dateTo}` : labels[period] };
}

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async revenue(staff: AuthenticatedStaff, query: AnalyticsQueryDto): Promise<RevenueResponse> {
    // Staff currently has no branch relation. Never infer manager access from user input.
    if (staff.role === StaffRole.MANAGER) {
      throw new ForbiddenException({ code: 'MANAGER_BRANCH_NOT_CONFIGURED', message: 'Manager branch assignment is required' });
    }
    if (![StaffRole.OWNER, StaffRole.DEVELOPER].includes(staff.role as 'OWNER' | 'DEVELOPER') || !staff.brandId) {
      throw new ForbiddenException();
    }
    const range = revenueRange(query);
    return this.prisma.$transaction(async tx => {
      if (query.branchId && !await tx.branch.findFirst({
        where: { id: query.branchId, deletedAt: null, brandBranches: { some: { brandId: staff.brandId } } },
        select: { id: true },
      })) throw new NotFoundException({ code: 'BRANCH_NOT_FOUND', message: 'Branch not found in staff brand' });

      const where: Prisma.OrderWhereInput = {
        brandId: staff.brandId, ...(query.branchId ? { branchId: query.branchId } : {}),
        status: OrderStatus.COMPLETED, deletedAt: null, completedAt: { gte: range.from, lt: range.end },
      };
      // Prisma groupBy cannot group timestamps by calendar date; use parameterized SQL for this aggregation.
      const daily = await tx.$queryRaw<Array<{ date: string; total: Prisma.Decimal; count: bigint }>>(Prisma.sql`
        SELECT to_char(completed_at AT TIME ZONE 'Europe/Moscow', 'YYYY-MM-DD') AS date,
               SUM(total_amount) AS total, COUNT(*) AS count
        FROM orders
        WHERE brand_id = ${staff.brandId}::uuid AND status = 'COMPLETED' AND deleted_at IS NULL
          AND completed_at >= ${range.from} AND completed_at < ${range.end}
          ${query.branchId ? Prisma.sql`AND branch_id = ${query.branchId}::uuid` : Prisma.empty}
        GROUP BY 1 ORDER BY 1
      `);
      const byDate = new Map(daily.map(row => [row.date, row]));
      const total = daily.reduce((sum, row) => sum.plus(row.total), new Prisma.Decimal(0));
      const count = daily.reduce((sum, row) => sum + Number(row.count), 0);
      const items = await tx.orderItem.groupBy({
        by: ['menuItemId'], where: { order: where },
        _sum: { quantity: true, totalAmount: true },
        orderBy: [{ _sum: { quantity: 'desc' } }, { menuItemId: 'asc' }], take: 5,
      });
      const topItems = await Promise.all(items.map(async item => {
        const snapshot = await tx.orderItem.findFirst({
          where: { menuItemId: item.menuItemId, order: where },
          orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], select: { name: true },
        });
        return { menuItemId: item.menuItemId, name: snapshot?.name ?? 'Блюдо',
          quantity: item._sum.quantity ?? 0, revenue: money(item._sum.totalAmount ?? new Prisma.Decimal(0)) };
      }));
      let byBranch: RevenueResponse['byBranch'];
      if (!query.branchId) {
        const groups = await tx.order.groupBy({ by: ['branchId'], where, _sum: { totalAmount: true }, _count: { _all: true }, orderBy: { branchId: 'asc' } });
        const branches = await tx.branch.findMany({ where: { id: { in: groups.map(g => g.branchId) } }, select: { id: true, name: true } });
        byBranch = groups.map(g => ({ branchId: g.branchId,
          branchName: branches.find(b => b.id === g.branchId)?.name ?? 'Филиал',
          total: money(g._sum.totalAmount ?? new Prisma.Decimal(0)), count: g._count._all }));
      }
      return {
        period: { from: range.from.toISOString(), to: new Date(range.end.getTime() - 1).toISOString(), label: range.label },
        summary: { total: money(total), ordersCount: count, averageCheck: count ? money(total.div(count)) : 0 },
        byDay: range.days.map(date => ({ date, total: money(byDate.get(date)?.total ?? new Prisma.Decimal(0)), count: Number(byDate.get(date)?.count ?? 0) })),
        topItems, ...(byBranch ? { byBranch } : {}),
      };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }
}
