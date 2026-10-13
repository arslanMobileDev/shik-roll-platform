import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Ip,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiTooManyRequestsResponse,
  ApiUnauthorizedResponse,
  getSchemaPath,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { AuthenticatedCustomer } from './auth.types';
import { CurrentCustomer } from './decorators/current-customer.decorator';
import { RestoreAccountDto } from './dto/restore-account.dto';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import {
  AuthTokensResponse,
  CustomerEntity,
  RestoreOfferResponse,
  SendOtpResponse,
} from './entities/auth.entities';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/send')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Send a 4-digit OTP code to the guest phone (non-production / DEV_OTP: fixed code 1111, also returned as devCode)',
  })
  @ApiOkResponse({ type: SendOtpResponse })
  @ApiTooManyRequestsResponse({
    description: 'OTP_SEND_RATE_LIMITED — one code per phone per minute',
  })
  sendOtp(@Body() dto: SendOtpDto, @Ip() ip: string): Promise<SendOtpResponse> {
    return this.auth.sendOtp(dto, ip);
  }

  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Verify the OTP code; auto-creates the customer on first sign-in and issues JWT access (30 days) + refresh tokens. ' +
      'If the phone belongs to a deleted account still inside its 30-day freeze window, answers 200 with status RESTORE_AVAILABLE ' +
      'and a restore token instead of a session — no account is created.',
  })
  @ApiOkResponse({
    description: 'AuthTokensResponse, or RestoreOfferResponse for a frozen number',
    schema: {
      oneOf: [
        { $ref: getSchemaPath(AuthTokensResponse) },
        { $ref: getSchemaPath(RestoreOfferResponse) },
      ],
    },
  })
  @ApiUnauthorizedResponse({ description: 'OTP_INVALID / OTP_EXPIRED' })
  @ApiTooManyRequestsResponse({
    description: 'OTP_ATTEMPTS_EXCEEDED — max 5 wrong attempts per code',
  })
  verifyOtp(
    @Body() dto: VerifyOtpDto,
  ): Promise<AuthTokensResponse | RestoreOfferResponse> {
    return this.auth.verifyOtp(dto);
  }

  @Post('restore')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Restore a deleted account from the restoreToken: clears the tombstone, returns the phone and signs the customer in. ' +
      'Order history comes back; bonuses burned by the deletion do not.',
  })
  @ApiOkResponse({ type: AuthTokensResponse })
  @ApiUnauthorizedResponse({ description: 'ACCOUNT_TOKEN_INVALID' })
  @ApiConflictResponse({
    description: 'RESTORE_CONFLICT / RESTORE_WINDOW_EXPIRED / ACCOUNT_NOT_DELETED',
  })
  restore(@Body() dto: RestoreAccountDto): Promise<AuthTokensResponse> {
    return this.auth.restoreAccount(dto.restoreToken);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Profile of the authenticated guest' })
  @ApiOkResponse({ type: CustomerEntity })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  me(@CurrentCustomer() customer: AuthenticatedCustomer): Promise<CustomerEntity> {
    return this.auth.getProfile(customer.id);
  }
}
