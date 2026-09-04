import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { AuthenticatedCustomer } from './auth.types';
import { CurrentCustomer } from './decorators/current-customer.decorator';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import {
  AuthTokensResponse,
  CustomerEntity,
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
      'Send a 4-digit OTP code to the guest phone (dev/test: fixed code 1234 when SMS_PROVIDER is not set)',
  })
  @ApiOkResponse({ type: SendOtpResponse })
  sendOtp(@Body() dto: SendOtpDto): Promise<SendOtpResponse> {
    return this.auth.sendOtp(dto);
  }

  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Verify the OTP code; auto-creates the customer on first sign-in and issues JWT access (30 days) + refresh tokens',
  })
  @ApiOkResponse({ type: AuthTokensResponse })
  @ApiUnauthorizedResponse({ description: 'OTP_INVALID / OTP_EXPIRED' })
  verifyOtp(@Body() dto: VerifyOtpDto): Promise<AuthTokensResponse> {
    return this.auth.verifyOtp(dto);
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
