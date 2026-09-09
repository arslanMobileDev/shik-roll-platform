import {
  BadGatewayException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { PaymentProvider, PaymentStatus } from '@prisma/client';
import {
  YOOKASSA_API_URL,
  YOOKASSA_RETURN_URL,
  YOOKASSA_SECRET_KEY,
  YOOKASSA_SHOP_ID,
  YOOKASSA_TAX_SYSTEM_CODE,
  YOOKASSA_VAT_CODE,
} from '../payments.config';
import {
  CreatePaymentSessionInput,
  ParsedPaymentWebhookEvent,
  PaymentProviderAdapter,
  PaymentSessionResult,
  YooKassaWebhookPayload,
  parseYooKassaWebhookEvent,
} from '../payments.types';

/** YooKassa payment object statuses mapped onto our lifecycle. */
const STATUS_MAP: Record<string, PaymentStatus> = {
  pending: PaymentStatus.PENDING,
  waiting_for_capture: PaymentStatus.PENDING,
  succeeded: PaymentStatus.SUCCEEDED,
  canceled: PaymentStatus.CANCELED,
};

interface YooKassaPaymentResponse {
  id?: string;
  status?: string;
  confirmation?: { confirmation_url?: string };
  metadata?: Record<string, string>;
}

/**
 * YooKassa HTTP API adapter (shop under Банк ВТБ): POST /v3/payments with
 * Basic auth and the Idempotence-Key header. The request carries the 54-ФЗ
 * receipt — when customer contact data is available, YooKassa forwards it
 * to the Атол Сигма online cash register (receipt_registration).
 */
@Injectable()
export class YooKassaProvider implements PaymentProviderAdapter {
  readonly provider = PaymentProvider.YOOKASSA;
  private readonly logger = new Logger(YooKassaProvider.name);

  async createPayment(
    input: CreatePaymentSessionInput,
  ): Promise<PaymentSessionResult> {
    const email = input.customer?.email ?? null;
    const phone = input.customer?.phone ?? null;
    const body = {
      amount: { value: input.amount.toFixed(2), currency: input.currency },
      confirmation: { type: 'redirect', return_url: YOOKASSA_RETURN_URL },
      capture: true,
      description: input.description,
      metadata: { orderId: input.orderId, paymentId: input.paymentId },
      ...(email || phone
        ? {
            receipt: {
              customer: {
                ...(email ? { email } : {}),
                ...(phone ? { phone } : {}),
              },
              items: input.receiptLines.map((line) => ({
                description: line.description.slice(0, 128),
                quantity: line.quantity,
                amount: {
                  value: line.unitPrice.toFixed(2),
                  currency: input.currency,
                },
                vat_code: YOOKASSA_VAT_CODE,
                payment_mode: 'full_payment',
                payment_subject: 'commodity',
              })),
              ...(YOOKASSA_TAX_SYSTEM_CODE
                ? { tax_system_code: YOOKASSA_TAX_SYSTEM_CODE }
                : {}),
            },
          }
        : {}),
    };

    let response: Response;
    try {
      response = await fetch(`${YOOKASSA_API_URL}/payments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Idempotence-Key': input.idempotenceKey,
          Authorization: `Basic ${Buffer.from(
            `${YOOKASSA_SHOP_ID}:${YOOKASSA_SECRET_KEY}`,
          ).toString('base64')}`,
        },
        body: JSON.stringify(body),
      });
    } catch (error) {
      this.logger.error(
        `YooKassa unreachable for order ${input.orderId}: ${String(error)}`,
      );
      throw new BadGatewayException({
        statusCode: 502,
        code: 'PAYMENT_PROVIDER_UNAVAILABLE',
        message: 'Payment provider is unavailable',
      });
    }

    if (!response.ok) {
      const details = await response.text();
      this.logger.error(
        `YooKassa rejected payment for order ${input.orderId}: HTTP ${response.status} ${details}`,
      );
      throw new BadGatewayException({
        statusCode: 502,
        code: 'PAYMENT_PROVIDER_ERROR',
        message: `Payment provider rejected the payment (HTTP ${response.status})`,
      });
    }

    const data = (await response.json()) as YooKassaPaymentResponse;
    if (!data.id || !data.status) {
      throw new BadGatewayException({
        statusCode: 502,
        code: 'PAYMENT_PROVIDER_ERROR',
        message: 'Payment provider returned a malformed payment object',
      });
    }

    return {
      externalPaymentId: data.id,
      paymentUrl: data.confirmation?.confirmation_url ?? null,
      status: STATUS_MAP[data.status] ?? PaymentStatus.PENDING,
    };
  }

  parseWebhookEvent(
    body: YooKassaWebhookPayload,
  ): ParsedPaymentWebhookEvent | null {
    return parseYooKassaWebhookEvent(body);
  }

  async verifyWebhook(
    _headers: Record<string, string | string[] | undefined>,
    body: YooKassaWebhookPayload,
  ): Promise<boolean> {
    const event = this.parseWebhookEvent(body);
    if (!event) return false;

    try {
      const response = await fetch(
        `${YOOKASSA_API_URL}/payments/${encodeURIComponent(event.paymentId)}`,
        {
          method: 'GET',
          headers: { Authorization: this.authorizationHeader() },
        },
      );
      if (!response.ok) {
        this.logger.warn(
          `Webhook verification failed for payment ${event.paymentId}: HTTP ${response.status}`,
        );
        return false;
      }

      const payment = (await response.json()) as YooKassaPaymentResponse;
      const expectedStatus =
        event.event === 'payment.succeeded' ? 'succeeded' : 'canceled';
      return (
        payment.id === event.paymentId &&
        payment.status === expectedStatus &&
        (!event.orderId || payment.metadata?.orderId === event.orderId)
      );
    } catch (error) {
      this.logger.warn(
        `Webhook verification unavailable for payment ${event.paymentId}: ${String(error)}`,
      );
      return false;
    }
  }

  private authorizationHeader(): string {
    return `Basic ${Buffer.from(
      `${YOOKASSA_SHOP_ID}:${YOOKASSA_SECRET_KEY}`,
    ).toString('base64')}`;
  }
}
