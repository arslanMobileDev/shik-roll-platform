import {
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { constantTimePinCheck } from '../tenant/pin-timing';
import { PrismaService } from '../../prisma/prisma.service';
import { resolveLoginRow } from '../tenant/resolve-login-row';
import { ACTIVE_TENANT_FILTER, TenantContext } from '../tenant/tenant.types';
import { STAFF_TOKEN_TTL_SECONDS } from './staff.config';
import { StaffPinAuthDto } from './dto/staff-auth.dto';
import { StaffTokenPayload } from './staff.types';

/** Result of a successful PIN login — token plus safe staff projection. */
export interface StaffAuthResponse {
  token: string;
  tokenType: 'Bearer';
  expiresInSeconds: number;
  staff: {
    id: string;
    name: string;
    role: string;
    brandId: string;
  };
}

/**
 * Back-office authentication (STAFF bounded context): phone + PIN -> JWT.
 * No self-registration — accounts are provisioned by an owner/developer.
 * Unknown phone and wrong PIN answer the same 401 (no account enumeration).
 */
@Injectable()
export class StaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async authenticateByPin(
    dto: StaffPinAuthDto,
    tenant?: TenantContext,
  ): Promise<StaffAuthResponse> {
    // Normalise: strip spaces, dashes, parentheses; keep leading +.
    // Accepts +7 928 313-51-91, +7(928)3135191, 89283135191 — all map
    // to the canonical +79283135191 stored in the DB.
    const phone = dto.phone.replace(/[\s\-()]/g, '');
    // `phone` is unique per tenant, not globally (ADR-1622 step 4b).
    const staff = await resolveLoginRow(
      tenant,
      () =>
        this.prisma.staff.findMany({
          where: { phone, tenant: ACTIVE_TENANT_FILTER },
          take: 2,
        }),
      (tenantId) =>
        this.prisma.staff.findUnique({
          // The tenant rides along in the same query as the composite key: the
          // middleware validated it a moment ago, but a tenant suspended in
          // between must not mint a token (same bypass the legacy branch closes).
          where: {
            tenantId_phone: { tenantId, phone },
            tenant: ACTIVE_TENANT_FILTER,
          },
        }),
    );
    const pinOk = await constantTimePinCheck(dto.pin, staff?.pinHash);
    if (!staff || !staff.isActive || !pinOk) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Invalid phone or PIN',
      });
    }

    const payload: StaffTokenPayload = {
      sub: staff.id,
      phone: staff.phone,
      role: staff.role,
      brandId: staff.brandId,
      type: 'access',
    };

    const token = await this.jwt.signAsync(payload, {
      expiresIn: STAFF_TOKEN_TTL_SECONDS,
    });

    return {
      token,
      tokenType: 'Bearer',
      expiresInSeconds: STAFF_TOKEN_TTL_SECONDS,
      staff: {
        id: staff.id,
        name: staff.name,
        role: staff.role,
        brandId: staff.brandId,
      },
    };
  }
}
