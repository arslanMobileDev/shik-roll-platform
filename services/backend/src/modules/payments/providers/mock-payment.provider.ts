import { Injectable, Logger } from '@nestjs/common';
import { PaymentProvider, PaymentStatus } from '@prisma/client';
import {
  CreatePaymentSessionInput,
  ParsedPaymentWebhookEvent,
  PaymentProviderAdapter,
  PaymentSessionResult,
  YooKassaWebhookPayload,
  parseYooKassaWebhookEvent,
} from '../payments.types';

/**
 * Dev-mode provider (no API keys configured): simulates YooKassa by
 * returning a test confirmation URL and an immediately SUCCEEDED session,
 * so the full payment flow (order confirmation included) is exercisable
 * in development and tests without touching the real API.
 */
@Injectable()
export class MockPaymentProvider implements PaymentProviderAdapter {
  readonly provider = PaymentProvider.YOOKASSA;
  private readonly logger = new Logger(MockPaymentProvider.name);

  createPayment(input: CreatePaymentSessionInput): Promise<PaymentSessionResult> {
    this.logger.log(
      `Mock payment session for order ${input.orderId} (${input.idempotenceKey})`,
    );
    return Promise.resolve({
      externalPaymentId: `mock-${input.paymentId}`,
      paymentUrl: `https://mock-pay.shik.local/payments/${input.paymentId}/confirm`,
      status: PaymentStatus.PENDING,
    });
  }

  verifyWebhook(
    _headers: Record<string, string | string[] | undefined>,
    body: YooKassaWebhookPayload,
  ): Promise<boolean> {
    return Promise.resolve(this.parseWebhookEvent(body) !== null);
  }

  parseWebhookEvent(
    body: YooKassaWebhookPayload,
  ): ParsedPaymentWebhookEvent | null {
    return parseYooKassaWebhookEvent(body);
  }
}
