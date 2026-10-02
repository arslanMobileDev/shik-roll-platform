import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../../prisma/prisma.service';
import { ACTIVE_TENANT_FILTER } from '../../tenant/tenant.types';
import {
  AuthenticatedKitchenTerminal,
  KitchenTokenPayload,
  RequestWithKitchen,
} from '../kitchen.types';

/**
 * Verifies the Bearer access token (JWT) issued by POST /kitchen/auth/pin and
 * attaches the terminal identity to the request as `kitchenTerminal`. Tokens
 * of other bounded contexts (CUSTOMER, COURIER, ...) are rejected.
 *
 * Unlike the courier guard, the terminal is re-read from the database on
 * every request (ADR-1618): a deactivated terminal's still-valid JWT stops
 * working immediately, and the branch binding comes from the authoritative
 * row rather than the issue-time claim.
 */
@Injectable()
export class KitchenJwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithKitchen>();
    const token = this.extractToken(request);
    if (!token) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Missing Bearer token',
      });
    }
    request.kitchenTerminal = await this.verify(token);
    return true;
  }

  private extractToken(request: RequestWithKitchen): string | undefined {
    const [scheme, token] = request.headers.authorization?.split(' ') ?? [];
    return scheme === 'Bearer' && token ? token : undefined;
  }

  private async verify(token: string): Promise<AuthenticatedKitchenTerminal> {
    let payload: KitchenTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<KitchenTokenPayload>(token);
      if (payload.type !== 'access' || payload.role !== 'KITCHEN') {
        throw new Error('Not a kitchen access token');
      }
    } catch {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Invalid or expired kitchen access token',
      });
    }

    const terminal = await this.prisma.kitchenTerminal.findUnique({
      // ADR-1622 A1-guard: a token minted while the tenant was active must stop
      // working the moment the tenant is suspended or soft-deleted. Filtering in
      // the row query makes that read as an ordinary "unknown terminal".
      where: { id: payload.sub, tenant: ACTIVE_TENANT_FILTER },
    });
    if (!terminal || !terminal.isActive) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TERMINAL_INACTIVE',
        message: 'Kitchen terminal is deactivated or unknown',
      });
    }
    return {
      id: terminal.id,
      code: terminal.code,
      name: terminal.name,
      tenantId: terminal.tenantId,
      branchId: terminal.branchId,
      role: 'KITCHEN',
    };
  }
}
