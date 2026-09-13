import {
  HttpException,
  HttpStatus,
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
  isDevOtpMode,
  OTP_MAX_ATTEMPTS,
  OTP_SEND_COOLDOWN_SECONDS,
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
import { SMS_PROVIDER, SmsProvider } from './providers/sms/sms.provider';

/**
 * Guest authentication by phone + one-time code (BE-906 surface).
 * The customer record is auto-provisioned on the first successful
 * verification; access tokens live 30 days, refresh tokens 90 days.
 *
 * Abuse controls (Redis-backed): one code per phone per minute, at most
 * OTP_MAX_ATTEMPTS wrong verifications per issued code, codes expire after
 * OTP_TTL_SECONDS. In production the OTP is never logged — only the masked
 * phone appears in log lines (152-FZ hygiene).
 */
@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @Inject(OTP_STORE) private readonly otpStore: OtpStore,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async sendOtp(dto: SendOtpDto, ip?: string): Promise<SendOtpResponse> {
    const slotAcquired = await this.otpStore.acquireSendSlot(
      dto.phone,
      OTP_SEND_COOLDOWN_SECONDS,
    );
    if (!slotAcquired) {
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          code: 'OTP_SEND_RATE_LIMITED',
          message: `OTP was already sent; retry in ${OTP_SEND_COOLDOWN_SECONDS} seconds`,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const devMode = isDevOtpMode();
    const code = devMode
      ? DEV_OTP_CODE
      : String(Math.floor(1000 + Math.random() * 9000));
    await this.otpStore.set(dto.phone, code, OTP_TTL_SECONDS);

    if (devMode) {
      // Dev/test only: fixed code 1111, no SMS is dispatched.
      this.logger.log(`OTP for ${dto.phone}: ${code} (dev mode, SMS not sent)`);
    } else {
      // Production: hand the code to the configured gateway. The provider
      // throws on transport failure so the client gets a 5xx and can retry;
      // the code is already stored with its TTL and stays valid.
      await this.sms.send(dto.phone, code, ip);
    }

    return {
      phone: dto.phone,
      expiresInSeconds: OTP_TTL_SECONDS,
      // Dev convenience for the mobile team; never present in production.
      ...(devMode ? { devCode: code } : {}),
    };
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<AuthTokensResponse> {
    const entry = await this.otpStore.get(dto.phone);
    if (entry === null) {
      throw new UnauthorizedException({
        statusCode: 401,
        code: 'OTP_EXPIRED',
        message: 'OTP code expired or was never requested',
      });
    }
    if (entry.code !== dto.code) {
      const attempts = await this.otpStore.incrementAttempts(dto.phone);
      if (attempts !== null && attempts >= OTP_MAX_ATTEMPTS) {
        // Burn the code: further guessing is blocked, a fresh code is required.
        await this.otpStore.delete(dto.phone);
        throw new HttpException(
          {
            statusCode: HttpStatus.TOO_MANY_REQUESTS,
            code: 'OTP_ATTEMPTS_EXCEEDED',
            message: 'Too many invalid OTP attempts; request a new code',
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
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
        { sub: customer.id, phone: customer.phone, role: customer.role, type: 'access' },
        { expiresIn: ACCESS_TOKEN_TTL_SECONDS },
      ),
      this.jwt.signAsync(
        { sub: customer.id, phone: customer.phone, role: customer.role, type: 'refresh' },
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

  /** Production logs carry only the masked phone (+7******11), never the OTP. */
  private maskPhone(phone: string): string {
    return phone.length > 4 ? `${phone.slice(0, 2)}******${phone.slice(-2)}` : '***';
  }
}
