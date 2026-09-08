import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
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
 */
@Injectable()
export class CourierJwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

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
    try {
      const payload = await this.jwt.verifyAsync<CourierTokenPayload>(token);
      if (payload.type !== 'access' || payload.role !== 'COURIER') {
        throw new Error('Not a courier access token');
      }
      return {
        id: payload.sub,
        phone: payload.phone,
        branchId: payload.branchId,
        role: 'COURIER',
      };
    } catch {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Invalid or expired courier access token',
      });
    }
  }
}
