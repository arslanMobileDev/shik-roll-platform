import { ApiProperty } from '@nestjs/swagger';
import { Matches } from 'class-validator';
import { PHONE_PATTERN } from './send-otp.dto';

export class VerifyOtpDto {
  @ApiProperty({
    description: 'Guest phone in E.164 format (+7XXXXXXXXXX)',
    example: '+79991234567',
  })
  @Matches(PHONE_PATTERN, { message: 'phone must be in +7XXXXXXXXXX format' })
  phone!: string;

  @ApiProperty({ description: '4-digit OTP code', example: '1234' })
  @Matches(/^\d{4}$/, { message: 'code must be a 4-digit number' })
  code!: string;
}
