import { PaymentProvider, PaymentStatus, Prisma } from '@prisma/client';

/** Injection token for the active payment provider adapter. */
export const PAYMENT_PROVIDER_ADAPTER = Symbol('PAYMENT_PROVIDER_ADAPTER');

/** One 54-ФЗ receipt line: a sold item with its per-unit price. */
export interface ReceiptLine {
  description: string;
  quantity: number;
  /** Per-unit price incl. modifiers, RUB; line sum = unitPrice x quantity. */
  unitPrice: Prisma.Decimal;
}

/** Customer contact for the fiscal receipt (email or phone required by 54-ФЗ). */
export interface ReceiptCustomer {
  email?: string | null;
  phone?: string | null;
}

export interface CreatePaymentSessionInput {
  /** Internal payment id (generated before the provider call). */
  paymentId: string;
  orderId: string;
  orderNumber: string;
  /** Sent to the provider as the Idempotence-Key header. */
  idempotenceKey: string;
  amount: Prisma.Decimal;
  currency: string;
  description: string;
  customer?: ReceiptCustomer;
  receiptLines: ReceiptLine[];
}

export interface PaymentSessionResult {
  /** Provider-side payment id (YooKassa object.id). */
  externalPaymentId: string | null;
  /** Redirect URL the customer opens to pay. */
  paymentUrl: string | null;
  /** Provider-reported status mapped onto our lifecycle. */
  status: PaymentStatus;
}

/**
 * Port of the payments bounded context (Port/Adapter, same convention as the
 * storage layer): the service speaks only to this interface; concrete
 * providers (YooKassa HTTP API, dev Mock) are swapped by PaymentsModule.
 */
export interface PaymentProviderAdapter {
  readonly provider: PaymentProvider;
  createSession(input: CreatePaymentSessionInput): Promise<PaymentSessionResult>;
}

/** YooKassa webhook notification payload (https://yookassa.ru/developers/using-api/webhooks). */
export interface YooKassaWebhookPayload {
  type?: string;
  event?: string;
  object?: {
    id?: string;
    status?: string;
    paid?: boolean;
    amount?: { value?: string; currency?: string };
    metadata?: Record<string, string>;
  };
}
