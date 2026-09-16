import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AnalyticsQueryDto, RevenuePeriod } from '../staff-analytics/dto/analytics-query.dto';
import { revenueRange } from '../staff-analytics/analytics.service';
import { AuthenticatedStaff } from '../staff/staff.types';
import { CooksService } from './cooks.service';
import { CookActor } from './cooks.dto';
import { COOK_TTL_MS } from './cook-session.service';
const round = (n: number) => Math.round(n * 100) / 100;
@Injectable()
export class CookStatisticsService {
    constructor(private readonly prisma: PrismaService, private readonly cooks: CooksService) { }
    private async metrics(where: Prisma.OrderStatusHistoryWhereInput) {
        const starts = await this.prisma.orderStatusHistory.findMany({ where: { ...where, newStatus: 'COOKING', previousStatus: { in: ['NEW', 'CONFIRMED'] } }, orderBy: { changedAt: 'asc' } });
        const ready = starts.length ? await this.prisma.orderStatusHistory.findMany({ where: { orderId: { in: starts.map(s => s.orderId) }, newStatus: 'READY' }, orderBy: { changedAt: 'asc' } }) : [];
        return starts.map(s => { const end = ready.find(e => e.orderId === s.orderId && e.changedAt >= s.changedAt); return { ...s, minutes: end ? (end.changedAt.getTime() - s.changedAt.getTime()) / 60000 : null }; });
    }
    private aggregate(rows: Array<{
        orderId: string;
        minutes: number | null;
    }>) {
        const unique = [...new Map(rows.map(r => [r.orderId, r])).values()];
        const measured = unique.filter(r => r.minutes !== null);
        return { ordersCooked: unique.length, averageCookingMinutes: measured.length ? round(measured.reduce((n, r) => n + r.minutes!, 0) / measured.length) : 0 };
    }
    async shifts(staff: AuthenticatedStaff, query: AnalyticsQueryDto) {
        const branch = await this.cooks.scope(staff, query.branchId);
        const range = revenueRange(query);
        const now = new Date();
        const shifts = await this.prisma.cookShift.findMany({ where: { branch, startedAt: { lt: range.end }, OR: [{ endedAt: null }, { endedAt: { gte: range.from } }] }, include: { cook: { select: { name: true } }, terminal: { select: { code: true } } }, orderBy: { startedAt: 'desc' } });
        const rows = await this.metrics({ shiftId: { in: shifts.map(s => s.id) }, order: { brandId: staff.brandId, deletedAt: null } });
        const records = shifts.filter(s => (s.endedAt ?? new Date(s.startedAt.getTime() + COOK_TTL_MS)) >= range.from).map(s => {
            const timedOut = s.startedAt.getTime() + COOK_TTL_MS <= now.getTime();
            const end = s.endedAt ?? (timedOut ? new Date(s.startedAt.getTime() + COOK_TTL_MS) : null);
            return { id: s.id, cookId: s.cookId, cookName: s.cook.name, branchId: s.branchId, terminalCode: s.terminal.code, startedAt: s.startedAt, endedAt: end, durationMinutes: Math.max(0, Math.floor(((end ?? now).getTime() - s.startedAt.getTime()) / 60000)), ...this.aggregate(rows.filter(r => r.shiftId === s.id)), isActive: end === null };
        });
        const total = records.reduce((n, s) => n + s.ordersCooked, 0);
        return { shifts: records, summary: { activeNow: records.filter(s => s.isActive).length, totalShifts: records.length, totalOrdersCooked: total, averageOrdersPerShift: records.length ? round(total / records.length) : 0 } };
    }
    async top(staff: AuthenticatedStaff, query: AnalyticsQueryDto) {
        const branch = await this.cooks.scope(staff, query.branchId);
        const range = revenueRange(query);
        const rows = await this.metrics({ cookId: { not: null }, changedAt: { gte: range.from, lt: range.end }, order: { brandId: staff.brandId, deletedAt: null, branch } });
        const people = await this.prisma.cook.findMany({ where: { id: { in: [...new Set(rows.map(r => r.cookId!))] } }, select: { id: true, name: true } });
        return { cooks: people.map(c => ({ cookId: c.id, name: c.name, ...this.aggregate(rows.filter(r => r.cookId === c.id)) })).sort((a, b) => b.ordersCooked - a.ordersCooked || a.cookId.localeCompare(b.cookId)).slice(0, 5) };
    }
    async personal(actor: CookActor, period: RevenuePeriod) {
        const now = new Date();
        const range = revenueRange({ period }, now);
        const last = revenueRange({ period: RevenuePeriod.CUSTOM, dateFrom: new Date(now.getTime() + 10800000 - 6 * 86400000).toISOString().slice(0, 10), dateTo: new Date(now.getTime() + 10800000).toISOString().slice(0, 10) }, now);
        const shift = await this.prisma.cookShift.findUniqueOrThrow({ where: { id: actor.shiftId } });
        const rows = await this.metrics({ cookId: actor.id, order: { deletedAt: null }, OR: [{ changedAt: { gte: range.from, lt: range.end } }, { changedAt: { gte: last.from, lt: last.end } }, { shiftId: actor.shiftId }] });
        return { period: { from: range.from, to: new Date(range.end.getTime() - 1), label: range.label }, ...this.aggregate(rows.filter(r => r.changedAt >= range.from && r.changedAt < range.end)), currentShift: { startedAt: shift.startedAt, durationMinutes: Math.max(0, Math.floor((now.getTime() - shift.startedAt.getTime()) / 60000)), ...this.aggregate(rows.filter(r => r.shiftId === shift.id)) }, last7Days: last.days.map(date => { const m = this.aggregate(rows.filter(r => new Date(r.changedAt.getTime() + 10800000).toISOString().slice(0, 10) === date)); return { date, ordersCooked: m.ordersCooked, averageMinutes: m.averageCookingMinutes }; }) };
    }
}
