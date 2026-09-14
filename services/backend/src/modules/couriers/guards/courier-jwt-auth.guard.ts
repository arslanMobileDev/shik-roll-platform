import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  AuthenticatedCourier,
  CourierTokenPayload,
  RequestWithCourier,
} from '../couriers.types';

/**
 * Verifies the Bearer access token (JWT) issued by POST /couriers/auth/pin and
 * attaches the courier identity to the request as `courier`. Tokens of other
 * bounded contexts (e.g. customer tokens with role CUSTOMER) are rejected:
 * courier endpoints accept courier tokens only.
 *
 * Mirrors the kitchen guard (ADR-1618): the courier row is re-read from the
 * database on every request, so deactivating a courier (is_active = false)
 * or deleting the row revokes already-issued JWTs immediately. The branch
 * binding always comes from the authoritative row, never from the token.
 */
@Injectable()
export class CourierJwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithCourier>();
    const token = this.extractToken(request);
    if (!token) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Missing Bearer token',
      });
    }
    request.courier = await this.verify(token);
    return true;
  }

  private extractToken(request: RequestWithCourier): string | undefined {
    const [scheme, token] = request.headers.authorization?.split(' ') ?? [];
    return scheme === 'Bearer' && token ? token : undefined;
  }

  private async verify(token: string): Promise<AuthenticatedCourier> {
    let payload: CourierTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<CourierTokenPayload>(token);
      if (payload.type !== 'access' || payload.role !== 'COURIER') {
        throw new Error('Not a courier access token');
      }
    } catch {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Invalid or expired courier access token',
      });
    }

    const courier = await this.prisma.courier.findUnique({
      where: { id: payload.sub },
      select: { id: true, phone: true, branchId: true, isActive: true },
    });
    if (!courier || !courier.isActive) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Courier is deactivated or unknown',
      });
    }
    return {
      id: courier.id,
      phone: courier.phone,
      branchId: courier.branchId,
      role: 'COURIER',
    };
  }
}
