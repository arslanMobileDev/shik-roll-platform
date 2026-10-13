import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../../prisma/prisma.service';
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
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

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
      if (payload.type !== 'access' ||
          typeof payload.sub !== 'string' || !payload.sub.trim() ||
          (payload.role !== undefined && payload.role !== 'CUSTOMER')) {
        throw new Error(`Unexpected token type: ${payload.type}`);
      }
      // Signature and expiry alone are not enough: deleting an account leaves
      // its 30-day access token cryptographically valid, and without this row
      // check the deleted customer would keep reading their order history.
      // Same PK lookup the courier and staff guards already do.
      const live = await this.prisma.customer.findUnique({
        where: { id: payload.sub, deletedAt: null },
        select: { id: true },
      });
      if (!live) {
        throw new Error('Customer no longer exists');
      }
      // Tokens minted before the role column existed fall back to CUSTOMER.
      return {
        id: payload.sub,
        phone: payload.phone ?? null,
        role: payload.role ?? 'CUSTOMER',
      };
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
