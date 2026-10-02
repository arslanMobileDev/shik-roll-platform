import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { ACTIVE_TENANT_FILTER } from '../tenant/tenant.types';
import { CookActor } from './cooks.dto';
export const COOK_TTL_MS = 8 * 60 * 60 * 1000;
@Injectable()
export class CookSessionService {
    constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) { }
    async verify(header?: string): Promise<CookActor> {
        const match = /^Bearer ([^ ]+)$/.exec(header ?? '');
        if (!match)
            throw new UnauthorizedException('Cook Bearer token required');
        let payload: {
            sub: string;
            role: string;
            type: string;
            shiftId: string;
            terminalId: string;
            branchId: string;
        };
        try {
            payload = await this.jwt.verifyAsync(match[1]);
        }
        catch {
            throw new UnauthorizedException('Invalid cook token');
        }
        if (payload.role !== 'COOK' || payload.type !== 'access')
            throw new ForbiddenException('Cook role required');
        if (!payload.sub || !payload.shiftId)
            throw new UnauthorizedException('Invalid cook session');
        // ADR-1622 A1: the tenant filter rides along in the same query (no extra
        // round trip). A shift is owned by the tenant of the terminal it was
        // opened at, so when that tenant is suspended or soft-deleted the row
        // stops resolving — the token dies with the tenant and answers the same
        // TOKEN_INVALID as a closed or revoked shift, leaving nothing that
        // distinguishes "suspended tenant" from "no such session".
        const shift = await this.prisma.cookShift.findUnique({
            where: { id: payload.shiftId, terminal: { tenant: ACTIVE_TENANT_FILTER } },
            include: { cook: true, terminal: true }
        });
        if (shift && !shift.endedAt && shift.startedAt.getTime() + COOK_TTL_MS <= Date.now()) {
            await this.prisma.cookShift.updateMany({ where: { id: shift.id, endedAt: null }, data: { endedAt: new Date(shift.startedAt.getTime() + COOK_TTL_MS), endedReason: 'timeout' } });
            throw new UnauthorizedException('Cook shift expired');
        }
        if (!shift || shift.endedAt || !shift.cook.isActive || !shift.terminal.isActive ||
            shift.startedAt.getTime() + COOK_TTL_MS <= Date.now() ||
            shift.cookId !== payload.sub || shift.branchId !== payload.branchId || shift.terminalId !== payload.terminalId ||
            shift.cook.branchId !== shift.branchId || shift.terminal.branchId !== shift.branchId) {
            throw new UnauthorizedException({
                statusCode: 401,
                code: 'TOKEN_INVALID',
                message: 'Cook shift is no longer active'
            });
        }
        return { id: shift.cookId, shiftId: shift.id, branchId: shift.branchId, terminalId: shift.terminalId };
    }
}
