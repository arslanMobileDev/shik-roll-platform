import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { ACCESS_TOKEN_TTL_SECONDS, JWT_SECRET } from './auth.config';
import { AuthService } from './auth.service';
import { createOtpStore, OTP_STORE } from './otp-store.service';

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
  providers: [AuthService, { provide: OTP_STORE, useFactory: createOtpStore }],
  exports: [AuthService, OTP_STORE],
})
export class AuthModule {}
