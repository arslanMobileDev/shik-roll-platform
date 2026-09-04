import { Payment } from '@prisma/client';
import { PaymentEntity } from '../entities/payment.entity';

export function toPaymentEntity(record: Payment): PaymentEntity {
  return {
    id: record.id,
    orderId: record.orderId,
    provider: record.provider,
    status: record.status,
    amount: record.amount.toNumber(),
    currency: record.currency,
    paymentUrl: record.paymentUrl,
    externalPaymentId: record.externalPaymentId,
    idempotenceKey: record.idempotenceKey,
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString(),
  };
}
