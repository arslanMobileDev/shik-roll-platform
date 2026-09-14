import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { ACCESS_TOKEN_TTL_SECONDS, JWT_SECRET } from './auth.config';
import { AuthService } from './auth.service';
import { createOtpStore, OTP_STORE } from './otp-store.service';
import { SMS_PROVIDER, SMS_PROVIDER_SMSRU, SmsProvider } from './providers/sms/sms.provider';
import { SmsRuProvider } from './providers/sms/smsru.provider';

/**
 * Guest authentication bounded context (phone + OTP -> JWT).
 * JwtModule is registered globally so sibling modules (orders) can verify
 * guest tokens on shared endpoints without importing this module's internals.
 */
@Module({
  imports: [
    JwtModule.register({
      global: true,
      secret: JWT_SECRET,
      signOptions: { expiresIn: ACCESS_TOKEN_TTL_SECONDS },
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    { provide: OTP_STORE, useFactory: createOtpStore },
    { provide: SMS_PROVIDER, useFactory: createSmsProvider },
  ],
  exports: [AuthService, OTP_STORE],
})
export class AuthModule {}

/**
 * Builds the SMS gateway from env. SMS_PROVIDER=smsru requires SMSRU_API_ID.
 * When SMS_PROVIDER is unset the module starts with a stub that refuses to
 * send — safe for dev/test where the OTP never leaves the process.
 */
function createSmsProvider(): SmsProvider {
  const provider = process.env.SMS_PROVIDER;
  if (!provider) {
    return {
      async send(): Promise<void> {
        throw new Error('SMS provider is not configured (SMS_PROVIDER is unset)');
      },
    };
  }
  if (provider === SMS_PROVIDER_SMSRU) {
    const apiId = process.env.SMSRU_API_ID;
    if (!apiId) {
      throw new Error('SMSRU_API_ID is required when SMS_PROVIDER=smsru');
    }
    return new SmsRuProvider(apiId);
  }
  throw new Error(`Unknown SMS_PROVIDER: ${provider}`);
}
