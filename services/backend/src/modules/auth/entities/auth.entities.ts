import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Customer, CustomerRole } from '@prisma/client';

export class CustomerEntity {
  @ApiProperty()
  id!: string;

  @ApiPropertyOptional({
    example: '+79991234567',
    description: 'Null once the account has been deleted and anonymized',
  })
  phone!: string | null;

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

/**
 * Alternative outcome of POST /auth/otp/verify: the code was correct, but the
 * phone belongs to a deleted account still inside its 30-day freeze window.
 * No session is issued — the client either POSTs the token to /auth/restore,
 * or leaves it. Cancelling deliberately creates nothing: the number stays
 * frozen and the same offer comes back on the next sign-in attempt.
 */
export class RestoreOfferResponse {
  @ApiProperty({ enum: ['RESTORE_AVAILABLE'], example: 'RESTORE_AVAILABLE' })
  status!: 'RESTORE_AVAILABLE';

  @ApiProperty({
    description: 'One-shot token for POST /auth/restore (5 minute TTL)',
  })
  restoreToken!: string;

  @ApiProperty({ description: 'Token lifetime in seconds', example: 300 })
  expiresInSeconds!: number;

  @ApiProperty({ description: 'When the account was deleted' })
  deletedAt!: string;
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
