import { Module } from '@nestjs/common';
import { paymentsProviderMode } from './payments.config';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { PAYMENT_PROVIDER_ADAPTER, PaymentProviderAdapter } from './payments.types';
import { MockPaymentProvider } from './providers/mock-payment.provider';
import { YooKassaProvider } from './providers/yookassa.provider';

/**
 * Payments bounded context. The active provider adapter is selected once at
 * module load: YooKassa when API keys are configured (PAYMENTS_PROVIDER or
 * YOOKASSA_SHOP_ID/YOOKASSA_SECRET_KEY), the dev Mock otherwise.
 */
@Module({
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    {
      provide: PAYMENT_PROVIDER_ADAPTER,
      useFactory: (): PaymentProviderAdapter =>
        paymentsProviderMode() === 'yookassa'
          ? new YooKassaProvider()
          : new MockPaymentProvider(),
    },
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}
