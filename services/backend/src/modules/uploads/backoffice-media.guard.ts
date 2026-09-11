import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

/** Expected payload shape of a backoffice staff access token. */
export interface BackofficeTokenPayload {
  sub: string;
  role: string;
  type: string;
}

/** Minimal request shape (avoids express type coupling, as in auth.types). */
export interface RequestWithBackofficeStaff {
  headers: { authorization?: string };
  backofficeStaff?: { id: string };
}

/**
 * Authorizes backoffice staff for menu media uploads (ADR-008).
 *
 * There is no staff persistence in the schema yet, so the trusted provider
 * is the BACKOFFICE_STAFF_IDS env allowlist (comma-separated staff UUIDs).
 * The token signature and expiry are always verified first; the subject must
 * then be present in the allowlist. When the allowlist is unset or empty no
 * trusted provider is configured and every request is denied — the endpoint
 * is never public. Guest (CUSTOMER), kitchen and courier tokens carry other
 * roles and are rejected as TOKEN_INVALID. When a DB-backed staff provider
 * lands, only this class changes.
 */
@Injectable()
export class BackofficeMediaGuard implements CanActivate {
  private readonly staffIds: Set<string>;

  constructor(private readonly jwt: JwtService) {
    const raw = process.env.BACKOFFICE_STAFF_IDS ?? '';
    this.staffIds = new Set(
      raw
        .split(',')
        .map((id) => id.trim())
        .filter((id) => id.length > 0),
    );
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<RequestWithBackofficeStaff>();
    const token = this.extractToken(request);
    if (!token) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Missing Bearer token',
      });
    }
    const staffId = await this.verify(token);
    if (!this.staffIds.has(staffId)) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'BACKOFFICE_FORBIDDEN',
        message: 'No backoffice media write permission',
      });
    }
    request.backofficeStaff = { id: staffId };
    return true;
  }

  private extractToken(
    request: RequestWithBackofficeStaff,
  ): string | undefined {
    const [scheme, token] = request.headers.authorization?.split(' ') ?? [];
    return scheme === 'Bearer' && token ? token : undefined;
  }

  private async verify(token: string): Promise<string> {
    try {
      const payload = await this.jwt.verifyAsync<BackofficeTokenPayload>(token);
      if (
        payload.type !== 'access' ||
        payload.role !== 'BACKOFFICE' ||
        !payload.sub
      ) {
        throw new Error('Not a backoffice access token');
      }
      return payload.sub;
    } catch {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'TOKEN_INVALID',
        message: 'Invalid or expired access token',
      });
    }
  }
}
