import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  AuthenticatedStaff,
  RequestWithStaff,
  StaffTokenPayload,
} from '../staff.types';

/**
 * Verifies the Bearer access token issued by POST /staff/auth/pin.
 * Tokens of other bounded contexts (CUSTOMER, COURIER, KITCHEN) carry a
 * different role and are rejected here.
 *
 * Like the kitchen guard: the staff row is re-read on every request, so
 * setting is_active=false revokes a still-valid JWT immediately. The
 * authoritative role and brand come from the row, not the token claim.
 */
@Injectable()
export class StaffJwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithStaff>();
    const token = this.extractToken(request);
    if (!token) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Missing Bearer token',
      });
    }
    request.staff = await this.verify(token);
    return true;
  }

  private extractToken(request: RequestWithStaff): string | undefined {
    const [scheme, token] = request.headers.authorization?.split(' ') ?? [];
    return scheme === 'Bearer' && token ? token : undefined;
  }

  private async verify(token: string): Promise<AuthenticatedStaff> {
    let payload: StaffTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<StaffTokenPayload>(token);
      if (payload.type !== 'access') {
        throw new Error('Not an access token');
      }
      if (
        payload.role !== 'OWNER' &&
        payload.role !== 'DEVELOPER' &&
        payload.role !== 'MANAGER'
      ) {
        throw new Error('Not a staff role');
      }
    } catch {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Invalid or expired staff access token',
      });
    }

    const staff = await this.prisma.staff.findUnique({
      where: { id: payload.sub },
      select: { id: true, phone: true, role: true, brandId: true, isActive: true },
    });
    if (!staff || !staff.isActive) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Staff account is deactivated or unknown',
      });
    }
    return {
      id: staff.id,
      phone: staff.phone,
      role: staff.role,
      brandId: staff.brandId,
    };
  }
}
