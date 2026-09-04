import {
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ACCESS_TOKEN_TTL_SECONDS,
  DEV_OTP_CODE,
  OTP_TTL_SECONDS,
  REFRESH_TOKEN_TTL_SECONDS,
} from './auth.config';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import {
  AuthTokensResponse,
  CustomerEntity,
  SendOtpResponse,
  toCustomerEntity,
} from './entities/auth.entities';
import { OTP_STORE, OtpStore } from './otp-store.service';

/**
 * Guest authentication by phone + one-time code (BE-906 surface).
 * The customer record is auto-provisioned on the first successful
 * verification; access tokens live 30 days, refresh tokens 90 days.
 */
@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @Inject(OTP_STORE) private readonly otpStore: OtpStore,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async sendOtp(dto: SendOtpDto): Promise<SendOtpResponse> {
    const code = this.generateCode();
    await this.otpStore.set(dto.phone, code, OTP_TTL_SECONDS);
    if (process.env.SMS_PROVIDER) {
      // SMS provider adapter is future work; the TTL-bounded code is stored
      // and ready to be dispatched once the provider integration lands.
      this.logger.log(`OTP generated for ${dto.phone} (provider: ${process.env.SMS_PROVIDER})`);
    } else {
      this.logger.log(`OTP for ${dto.phone}: ${code} (dev mode, SMS_PROVIDER not set)`);
    }
    return { phone: dto.phone, expiresInSeconds: OTP_TTL_SECONDS };
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<AuthTokensResponse> {
    const stored = await this.otpStore.get(dto.phone);
    if (stored === null) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'OTP_EXPIRED',
        message: 'OTP code expired or was never requested',
      });
    }
    if (stored !== dto.code) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'OTP_INVALID',
        message: 'Invalid OTP code',
      });
    }
    // One-time use: a verified code cannot be replayed.
    await this.otpStore.delete(dto.phone);

    const customer = await this.prisma.customer.upsert({
      where: { phone: dto.phone },
      create: { phone: dto.phone },
      update: {},
    });

    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(
        { sub: customer.id, phone: customer.phone, type: 'access' },
        { expiresIn: ACCESS_TOKEN_TTL_SECONDS },
      ),
      this.jwt.signAsync(
        { sub: customer.id, phone: customer.phone, type: 'refresh' },
        { expiresIn: REFRESH_TOKEN_TTL_SECONDS },
      ),
    ]);

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresInSeconds: ACCESS_TOKEN_TTL_SECONDS,
      customer: toCustomerEntity(customer),
    };
  }

  async getProfile(customerId: string): Promise<CustomerEntity> {
    const customer = await this.prisma.customer.findUnique({
      where: { id: customerId },
    });
    if (!customer) {
      throw new NotFoundException({
        statusCode: 404,
        code: 'CUSTOMER_NOT_FOUND',
        message: `Customer ${customerId} not found`,
      });
    }
    return toCustomerEntity(customer);
  }

  /** Dev/test uses the fixed code; production generates a random 4-digit one. */
  private generateCode(): string {
    if (!process.env.SMS_PROVIDER) {
      return DEV_OTP_CODE;
    }
    return String(Math.floor(1000 + Math.random() * 9000));
  }
}
