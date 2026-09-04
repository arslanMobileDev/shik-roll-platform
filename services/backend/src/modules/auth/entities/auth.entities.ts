import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Customer } from '@prisma/client';

export class CustomerEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty({ example: '+79991234567' })
  phone!: string;

  @ApiPropertyOptional()
  name!: string | null;

  @ApiPropertyOptional()
  email!: string | null;

  @ApiProperty()
  createdAt!: string;

  @ApiProperty()
  updatedAt!: string;
}

export class SendOtpResponse {
  @ApiProperty({ example: '+79991234567' })
  phone!: string;

  @ApiProperty({ description: 'OTP lifetime in seconds', example: 180 })
  expiresInSeconds!: number;
}

export class AuthTokensResponse {
  @ApiProperty({ description: 'JWT access token (30 days)' })
  accessToken!: string;

  @ApiProperty({ description: 'JWT refresh token' })
  refreshToken!: string;

  @ApiProperty({ example: 'Bearer' })
  tokenType!: string;

  @ApiProperty({ description: 'Access token lifetime in seconds' })
  expiresInSeconds!: number;

  @ApiProperty({ type: CustomerEntity })
  customer!: CustomerEntity;
}

export function toCustomerEntity(record: Customer): CustomerEntity {
  return {
    id: record.id,
    phone: record.phone,
    name: record.name,
    email: record.email,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}
