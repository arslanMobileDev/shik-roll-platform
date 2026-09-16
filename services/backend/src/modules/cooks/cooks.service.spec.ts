import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { CooksService } from './cooks.service';
import { CookSessionService, COOK_TTL_MS } from './cook-session.service';
import { CookStatisticsService } from './cook-statistics.service';
const staff = { id: 'owner', role: 'OWNER', brandId: 'brand' } as any;
const terminal = { id: 'terminal', branchId: 'branch' } as any;
const actor = { id: 'cook', shiftId: 'shift', terminalId: 'terminal', branchId: 'branch' };
describe('Cook identity, shifts and metrics', () => {
    let db: any, jwt: JwtService, service: CooksService, cook: any, shift: any;
    beforeEach(async () => {
        cook = { id: 'cook', name: 'Иван', phone: '+79280000000', pinHash: await bcrypt.hash('1234', 4), isActive: true, branchId: 'branch' };
        shift = { id: 'shift', cookId: 'cook', terminalId: 'terminal', branchId: 'branch', startedAt: new Date(), endedAt: null, cook, terminal: { isActive: true, branchId: 'branch' } };
        db = { branch: { findFirst: jest.fn().mockResolvedValue({ id: 'branch' }) }, cook: { findUnique: jest.fn().mockResolvedValue(cook), findUniqueOrThrow: jest.fn().mockResolvedValue(cook), create: jest.fn().mockResolvedValue({ id: 'cook' }), findFirst: jest.fn().mockResolvedValue(cook), update: jest.fn().mockResolvedValue({ id: 'cook' }) }, kitchenTerminal: { findUniqueOrThrow: jest.fn().mockResolvedValue({ isActive: true, branchId: 'branch' }) }, cookShift: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue(shift), updateMany: jest.fn().mockResolvedValue({ count: 1 }), findUnique: jest.fn().mockResolvedValue(shift), findUniqueOrThrow: jest.fn().mockResolvedValue(shift) }, $executeRaw: jest.fn().mockResolvedValue(0), $queryRaw: jest.fn().mockResolvedValue([]) };
        db.$transaction = jest.fn((fn: any) => fn(db));
        jwt = new JwtService({ secret: 'cook-test' });
        service = new CooksService(db, jwt);
    });
    it('creates cook with bcrypt hash and without exposing hash', async () => { await service.create(staff, { name: 'Иван', phone: cook.phone, pin: '1234', branchId: 'branch' }); const args = db.cook.create.mock.calls[0][0]; expect(args.data.pinHash).not.toBe('1234'); expect(await bcrypt.compare('1234', args.data.pinHash)).toBe(true); expect(args.select.pinHash).toBeUndefined(); });
    it('opens a scoped shift and issues an eight-hour cook JWT', async () => { const result = await service.login(terminal, { phone: cook.phone, pin: '1234' }); expect(jwt.verify(result.token)).toMatchObject({ sub: 'cook', role: 'COOK', shiftId: 'shift', terminalId: 'terminal' }); expect(db.cookShift.create).toHaveBeenCalledTimes(1); });
    it('reuses existing shift on duplicate login', async () => { db.cookShift.findFirst.mockResolvedValue(shift); const result = await service.login(terminal, { phone: cook.phone, pin: '1234' }); expect(result.shiftId).toBe('shift'); expect(db.cookShift.create).not.toHaveBeenCalled(); });
    it.each(['wrong', 'inactive', 'branch'])('rejects %s login', async (mode) => { if (mode === 'inactive')
        cook.isActive = false; if (mode === 'branch')
        cook.branchId = 'other'; await expect(service.login(terminal, { phone: cook.phone, pin: mode === 'wrong' ? '9999' : '1234' })).rejects.toThrow(); expect(db.cookShift.create).not.toHaveBeenCalled(); });
    it('closes only authenticated shift', async () => { await service.logout(actor); expect(db.cookShift.updateMany).toHaveBeenCalledWith({ where: { id: 'shift', cookId: 'cook', endedAt: null }, data: { endedAt: expect.any(Date), endedReason: 'logout' } }); });
    it('rejects closed, expired and deactivated personal sessions', async () => { const sessions = new CookSessionService(db, jwt); const token = jwt.sign({ sub: 'cook', role: 'COOK', type: 'access', shiftId: 'shift', terminalId: 'terminal', branchId: 'branch' }); await expect(sessions.verify('Bearer ' + token)).resolves.toEqual(actor); shift.endedAt = new Date(); await expect(sessions.verify('Bearer ' + token)).rejects.toThrow(); shift.endedAt = null; shift.startedAt = new Date(Date.now() - COOK_TTL_MS - 1); await expect(sessions.verify('Bearer ' + token)).rejects.toThrow(); shift.startedAt = new Date(); cook.isActive = false; await expect(sessions.verify('Bearer ' + token)).rejects.toThrow(); });
    it('requires owner scope for management', async () => { await expect(service.list({ ...staff, role: 'MANAGER' }, 'branch')).rejects.toThrow(); db.branch.findFirst.mockResolvedValue(null); await expect(service.list(staff, 'other')).rejects.toThrow(); });
    it('counts started orders and averages only measured COOKING to READY pairs', async () => {
        const start = new Date();
        db.cookShift.findMany = jest.fn().mockResolvedValue([{ ...shift, cook: { name: 'Иван' }, terminal: { code: 'KDS-01' } }]);
        db.orderStatusHistory = { findMany: jest.fn().mockResolvedValueOnce([{ orderId: 'a', shiftId: 'shift', cookId: 'cook', changedAt: start }, { orderId: 'b', shiftId: 'shift', cookId: 'cook', changedAt: start }]).mockResolvedValueOnce([{ orderId: 'a', newStatus: 'READY', changedAt: new Date(start.getTime() + 210000) }]) };
        const result = await new CookStatisticsService(db, service).shifts(staff, {});
        expect(result.shifts[0]).toMatchObject({ ordersCooked: 2, averageCookingMinutes: 3.5, isActive: true });
        expect(result.summary).toMatchObject({ totalOrdersCooked: 2, totalShifts: 1 });
    });
});
