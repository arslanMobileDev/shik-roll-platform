import {
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../prisma/prisma.service';
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

  async authenticateByPin(dto: StaffPinAuthDto): Promise<StaffAuthResponse> {
    const staff = await this.prisma.staff.findUnique({
      where: { phone: dto.phone },
    });
    if (!staff || !staff.isActive || !(await bcrypt.compare(dto.pin, staff.pinHash))) {
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
