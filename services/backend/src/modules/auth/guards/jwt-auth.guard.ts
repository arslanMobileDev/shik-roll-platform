import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  AuthenticatedCustomer,
  CustomerTokenPayload,
  RequestWithCustomer,
} from '../auth.types';

/**
 * Verifies the Bearer access token (JWT) and attaches the guest identity to
 * the request as `customer`. Rejects requests without a valid token.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithCustomer>();
    const token = this.extractToken(request);
    if (!token) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Missing Bearer token',
      });
    }
    request.customer = await this.verify(token);
    return true;
  }

  protected extractToken(request: RequestWithCustomer): string | undefined {
    const [scheme, token] = request.headers.authorization?.split(' ') ?? [];
    return scheme === 'Bearer' && token ? token : undefined;
  }

  protected async verify(token: string): Promise<AuthenticatedCustomer> {
    try {
      const payload = await this.jwt.verifyAsync<CustomerTokenPayload>(token);
      if (payload.type !== 'access') {
        throw new Error(`Unexpected token type: ${payload.type}`);
      }
      return { id: payload.sub, phone: payload.phone };
    } catch {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Invalid or expired access token',
      });
    }
  }
}

/**
 * Same verification, but anonymous requests (no Authorization header) pass
 * through with `customer` left undefined — used on endpoints shared between
 * guests (mobile app) and staff (POS / back office).
 */
@Injectable()
export class OptionalJwtAuthGuard extends JwtAuthGuard {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithCustomer>();
    const token = this.extractToken(request);
    if (!token) {
      return true;
    }
    request.customer = await this.verify(token);
    return true;
  }
}
