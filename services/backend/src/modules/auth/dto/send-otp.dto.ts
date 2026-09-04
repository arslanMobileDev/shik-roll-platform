import { ApiProperty } from '@nestjs/swagger';
import { Matches } from 'class-validator';

export const PHONE_PATTERN = /^\+7\d{10}$/;

export class SendOtpDto {
  @ApiProperty({
    description: 'Guest phone in E.164 format (+7XXXXXXXXXX)',
    example: '+79991234567',
  })
  @Matches(PHONE_PATTERN, { message: 'phone must be in +7XXXXXXXXXX format' })
  phone!: string;
}
