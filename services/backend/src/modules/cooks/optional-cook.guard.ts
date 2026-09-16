import { CookRequest } from './cooks.dto';
import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { CookSessionService } from './cook-session.service';
@Injectable()
export class OptionalCookGuard implements CanActivate {
    constructor(private readonly sessions: CookSessionService) { }
    async canActivate(ctx: ExecutionContext) {
        const req = ctx.switchToHttp().getRequest<CookRequest>();
        const header = req.headers['x-cook-authorization'];
        if (header === undefined)
            return true;
        req.cook = await this.sessions.verify(typeof header === 'string' ? header : '');
        if (req.cook.terminalId !== req.kitchenTerminal.id || req.cook.branchId !== req.kitchenTerminal.branchId)
            throw new ForbiddenException('Cook belongs to another terminal');
        return true;
    }
}
