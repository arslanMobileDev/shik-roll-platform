import { CookRequest } from './cooks.dto';
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { CookSessionService } from './cook-session.service';
@Injectable()
export class CookJwtAuthGuard implements CanActivate {
    constructor(private readonly sessions: CookSessionService) { }
    async canActivate(ctx: ExecutionContext) { const req = ctx.switchToHttp().getRequest<CookRequest>(); req.cook = await this.sessions.verify(req.headers.authorization); return true; }
}
