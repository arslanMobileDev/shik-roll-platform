import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PaymentProvider, PaymentStatus } from '@prisma/client';

export class PaymentEntity {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  orderId!: string;

  @ApiProperty({ enum: PaymentProvider })
  provider!: PaymentProvider;

  @ApiProperty({ enum: PaymentStatus })
  status!: PaymentStatus;

  @ApiProperty({ description: 'Payment amount in RUB (server-side order total)' })
  amount!: number;

  @ApiProperty()
  currency!: string;

  @ApiPropertyOptional({ description: 'Redirect URL the customer opens to pay' })
  paymentUrl!: string | null;

  @ApiPropertyOptional({ description: 'Provider-side payment id (YooKassa object.id)' })
  externalPaymentId!: string | null;

  @ApiProperty()
  idempotenceKey!: string;

  @ApiProperty()
  createdAt!: string;

  @ApiProperty()
  updatedAt!: string;
}

/** Payment status check for an order: the latest payment attempt, if any. */
export class OrderPaymentStatusEntity {
  @ApiProperty()
  orderId!: string;

  @ApiPropertyOptional({ type: PaymentEntity, nullable: true })
  payment!: PaymentEntity | null;
}
