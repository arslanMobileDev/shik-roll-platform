import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
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

  @Post('webhook/yookassa')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'YooKassa webhook receiver (payment.succeeded confirms the order); always 200, unknown payments are acknowledged and ignored',
  })
  @ApiOkResponse({ schema: { properties: { status: { type: 'string', enum: ['processed', 'ignored'] } } } })
  yooKassaWebhook(
    @Body() payload: YooKassaWebhookPayload,
  ): Promise<{ status: 'processed' | 'ignored' }> {
    return this.service.handleYooKassaWebhook(payload);
  }

  @Get('order/:orderId')
  @ApiOperation({ summary: 'Latest payment attempt for an order (payment status check)' })
  @ApiOkResponse({ type: OrderPaymentStatusEntity })
  getOrderPayment(
    @Param('orderId', ParseUUIDPipe) orderId: string,
  ): Promise<OrderPaymentStatusEntity> {
    return this.service.getOrderPayment(orderId);
  }
}
