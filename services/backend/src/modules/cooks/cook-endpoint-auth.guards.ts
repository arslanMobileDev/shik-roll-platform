import { ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { KitchenJwtAuthGuard } from '../kitchen/guards/kitchen-jwt-auth.guard';
import { StaffJwtAuthGuard } from '../staff/guards/staff-jwt-auth.guard';
async function checkRole(ctx: ExecutionContext, jwt: JwtService, roles: string[]) {
    const header = ctx.switchToHttp().getRequest<{
        headers: {
            authorization?: string;
        };
    }>().headers.authorization;
    const token = /^Bearer ([^ ]+)$/.exec(header ?? '')?.[1];
    if (!token)
        throw new UnauthorizedException('Bearer token required');
    let payload: {
        role?: string;
        type?: string;
    };
    try {
        payload = await jwt.verifyAsync(token);
    }
    catch {
        throw new UnauthorizedException('Invalid token');
    }
    if (payload.type !== 'access')
        throw new UnauthorizedException('Access token required');
    if (!roles.includes(payload.role ?? ''))
        throw new ForbiddenException('Role is not allowed');
}
/** New cooks routes distinguish valid wrong-role credentials (403) from missing/invalid tokens (401). Existing auth guards are unchanged. */
@Injectable()
export class CookTerminalAuthGuard extends KitchenJwtAuthGuard {
    constructor(private readonly roleJwt: JwtService, prisma: PrismaService) { super(roleJwt, prisma); }
    override async canActivate(ctx: ExecutionContext) { await checkRole(ctx, this.roleJwt, ['KITCHEN']); return super.canActivate(ctx); }
}
@Injectable()
export class CookStaffAuthGuard extends StaffJwtAuthGuard {
    constructor(private readonly roleJwt: JwtService, prisma: PrismaService) { super(roleJwt, prisma); }
    override async canActivate(ctx: ExecutionContext) {
        await checkRole(ctx, this.roleJwt, ['OWNER', 'DEVELOPER', 'MANAGER']);
        await super.canActivate(ctx);
        const role = ctx.switchToHttp().getRequest<{
            staff: {
                role: string;
            };
        }>().staff.role;
        if (!['OWNER', 'DEVELOPER'].includes(role))
            throw new ForbiddenException('Owner access required');
        return true;
    }
}
