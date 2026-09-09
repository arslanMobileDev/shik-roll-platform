import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Logger,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CreatePaymentDto } from './dto/create-payment.dto';
import {
  OrderPaymentStatusEntity,
  PaymentEntity,
} from './entities/payment.entity';
import { PaymentsService } from './payments.service';
import { YooKassaWebhookPayload } from './payments.types';

@ApiTags('payments')
@Controller('payments')
export class PaymentsController {
  private readonly logger = new Logger(PaymentsController.name);

  constructor(private readonly service: PaymentsService) {}

  @Post('create')
  @ApiOperation({
    summary:
      'Create an online payment session for an order; amount is the server-side order total, repeated calls reuse the pending attempt',
  })
  @ApiCreatedResponse({ type: PaymentEntity })
  create(@Body() dto: CreatePaymentDto): Promise<PaymentEntity> {
    return this.service.createPayment(dto);
  }

  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'YooKassa webhook receiver (payment.succeeded confirms the order); always 200, unknown payments are acknowledged and ignored',
  })
  @ApiOkResponse({ schema: { properties: { status: { type: 'string', enum: ['processed', 'ignored'] } } } })
  webhook(
    @Headers() headers: Record<string, string | string[] | undefined>,
    @Body() payload: YooKassaWebhookPayload,
  ): Promise<{ status: 'processed' | 'ignored' }> {
    return this.acknowledgeWebhook(headers, payload);
  }

  @Post('webhook/yookassa')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Legacy alias of POST /payments/webhook' })
  @ApiOkResponse({ schema: { properties: { status: { type: 'string' } } } })
  yooKassaWebhook(
    @Headers() headers: Record<string, string | string[] | undefined>,
    @Body() payload: YooKassaWebhookPayload,
  ): Promise<{ status: 'processed' | 'ignored' }> {
    return this.acknowledgeWebhook(headers, payload);
  }

  @Get('order/:orderId')
  @ApiOperation({ summary: 'Latest payment attempt for an order (payment status check)' })
  @ApiOkResponse({ type: OrderPaymentStatusEntity })
  getOrderPayment(
    @Param('orderId', ParseUUIDPipe) orderId: string,
  ): Promise<OrderPaymentStatusEntity> {
    return this.service.getOrderPayment(orderId);
  }

  private async acknowledgeWebhook(
    headers: Record<string, string | string[] | undefined>,
    payload: YooKassaWebhookPayload,
  ): Promise<{ status: 'processed' | 'ignored' }> {
    try {
      return await this.service.handleWebhook(headers, payload);
    } catch (error) {
      // YooKassa requires HTTP 200. Operational errors are logged by the
      // service and acknowledged so the public endpoint never leaks details.
      this.logger.error(`Webhook processing failed: ${String(error)}`);
      return { status: 'ignored' };
    }
  }
}
