import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Customer, CustomerRole } from '@prisma/client';

export class CustomerEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty({ example: '+79991234567' })
  phone!: string;

  @ApiPropertyOptional()
  name!: string | null;

  @ApiPropertyOptional()
  email!: string | null;

  @ApiProperty({ enum: CustomerRole, example: CustomerRole.CUSTOMER })
  role!: CustomerRole;

  @ApiProperty()
  createdAt!: string;

  @ApiProperty()
  updatedAt!: string;
}

export class SendOtpResponse {
  @ApiProperty({ example: '+79991234567' })
  phone!: string;

  @ApiProperty({ description: 'OTP lifetime in seconds', example: 300 })
  expiresInSeconds!: number;

  @ApiPropertyOptional({
    description:
      'Fixed dev code, returned only outside production (or with DEV_OTP=true); never present when a real SMS is dispatched',
    example: '1111',
  })
  devCode?: string;
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
    role: record.role,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}
