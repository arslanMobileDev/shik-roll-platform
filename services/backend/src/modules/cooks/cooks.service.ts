import { ConflictException, ForbiddenException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthenticatedStaff } from '../staff/staff.types';
import { AuthenticatedKitchenTerminal } from '../kitchen/kitchen.types';
import { CookActor, CookLoginDto, CreateCookDto, UpdateCookDto } from './cooks.dto';
import { COOK_TTL_MS } from './cook-session.service';
const publicCook = { id: true, name: true, phone: true, branchId: true, isActive: true } as const;
@Injectable()
export class CooksService {
    constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) { }
    async scope(staff: AuthenticatedStaff, branchId?: string) {
        if (!['OWNER', 'DEVELOPER'].includes(staff.role))
            throw new ForbiddenException('Owner access required');
        if (branchId && !await this.prisma.branch.findFirst({ where: { id: branchId, deletedAt: null, brandBranches: { some: { brandId: staff.brandId } } } }))
            throw new NotFoundException('Branch not found');
        return { ...(branchId ? { id: branchId } : {}), deletedAt: null, brandBranches: { some: { brandId: staff.brandId } } };
    }
    async list(staff: AuthenticatedStaff, branchId: string) { const branch = await this.scope(staff, branchId); return this.prisma.cook.findMany({ where: { branch }, select: publicCook, orderBy: { name: 'asc' } }); }
    async create(staff: AuthenticatedStaff, dto: CreateCookDto) {
        await this.scope(staff, dto.branchId);
        try {
            return await this.prisma.cook.create({ data: { name: dto.name, phone: dto.phone, branchId: dto.branchId, pinHash: await bcrypt.hash(dto.pin, 12) }, select: publicCook });
        }
        catch (e) {
            if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002')
                throw new ConflictException('Phone already registered');
            throw e;
        }
    }
    async update(staff: AuthenticatedStaff, id: string, dto: UpdateCookDto) {
        const branch = await this.scope(staff);
        const cook = await this.prisma.cook.findFirst({ where: { id, branch } });
        if (!cook)
            throw new NotFoundException('Cook not found');
        const pinHash = dto.pin ? await bcrypt.hash(dto.pin, 12) : undefined;
        return this.prisma.$transaction(async (tx) => {
            await tx.$queryRaw `SELECT id FROM cooks WHERE id = ${id}::uuid FOR UPDATE`;
            const result = await tx.cook.update({ where: { id }, data: { name: dto.name, isActive: dto.isActive, pinHash }, select: publicCook });
            if (dto.isActive === false || pinHash)
                await tx.cookShift.updateMany({ where: { cookId: id, endedAt: null }, data: { endedAt: new Date(), endedReason: 'shift_change' } });
            return result;
        });
    }
    async login(terminal: AuthenticatedKitchenTerminal, dto: CookLoginDto) {
        const cook = await this.prisma.cook.findUnique({ where: { phone: dto.phone } });
        if (!cook || !cook.isActive || !await bcrypt.compare(dto.pin, cook.pinHash))
            throw new UnauthorizedException('Invalid phone or PIN');
        if (cook.branchId !== terminal.branchId)
            throw new ForbiddenException('Cook belongs to another branch');
        const shift = await this.prisma.$transaction(async (tx) => {
            // Lock cook then terminal: serialize duplicate logins, deactivation and terminal handover.
            await tx.$queryRaw `SELECT id FROM cooks WHERE id = ${cook.id}::uuid FOR UPDATE`;
            await tx.$queryRaw `SELECT id FROM kitchen_terminals WHERE id = ${terminal.id}::uuid FOR UPDATE`;
            const fresh = await tx.cook.findUniqueOrThrow({ where: { id: cook.id } });
            const station = await tx.kitchenTerminal.findUniqueOrThrow({ where: { id: terminal.id } });
            if (!fresh.isActive || fresh.pinHash !== cook.pinHash || !station.isActive || station.branchId !== fresh.branchId)
                throw new UnauthorizedException('Session unavailable');
            const now = new Date();
            await tx.$executeRaw `UPDATE cook_shifts SET ended_at = started_at + interval '8 hours', ended_reason = 'timeout' WHERE ended_at IS NULL AND (cook_id = ${cook.id}::uuid OR terminal_id = ${terminal.id}::uuid) AND started_at <= ${new Date(now.getTime() - COOK_TTL_MS)}`;
            const existing = await tx.cookShift.findFirst({ where: { cookId: cook.id, terminalId: terminal.id, endedAt: null } });
            if (existing)
                return existing;
            await tx.cookShift.updateMany({ where: { endedAt: null, OR: [{ cookId: cook.id }, { terminalId: terminal.id }] }, data: { endedAt: now, endedReason: 'shift_change' } });
            return tx.cookShift.create({ data: { cookId: cook.id, terminalId: terminal.id, branchId: terminal.branchId, startedAt: now } });
        });
        const expiresIn = Math.max(1, Math.floor((shift.startedAt.getTime() + COOK_TTL_MS - Date.now()) / 1000));
        const token = await this.jwt.signAsync({ sub: cook.id, phone: cook.phone, role: 'COOK', type: 'access', branchId: cook.branchId, terminalId: terminal.id, shiftId: shift.id }, { expiresIn });
        return { token, shiftId: shift.id, cook: { id: cook.id, name: cook.name, branchId: cook.branchId } };
    }
    async logout(actor: CookActor) { await this.prisma.cookShift.updateMany({ where: { id: actor.shiftId, cookId: actor.id, endedAt: null }, data: { endedAt: new Date(), endedReason: 'logout' } }); return { success: true }; }
    async me(actor: CookActor) { return { cook: await this.prisma.cook.findUniqueOrThrow({ where: { id: actor.id }, select: publicCook }), currentShift: await this.prisma.cookShift.findUnique({ where: { id: actor.shiftId } }) }; }
}
