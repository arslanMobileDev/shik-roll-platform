import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthenticatedCustomer } from '../auth/auth.types';
import { CurrentCustomer } from '../auth/decorators/current-customer.decorator';
import { OptionalJwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderQueryDto } from './dto/order-query.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { OrderEntity, OrderPage } from './entities/order.entity';
import { OrdersService } from './orders.service';

@ApiTags('orders')
@Controller('orders')
export class OrdersController {
  constructor(private readonly service: OrdersService) {}

  @Post()
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({
    summary:
      'Create an order from POS or the mobile app; a guest Bearer token binds the order to the customer',
  })
  @ApiCreatedResponse({ type: OrderEntity })
  create(
    @Body() dto: CreateOrderDto,
    @CurrentCustomer() customer?: AuthenticatedCustomer,
  ): Promise<OrderEntity> {
    return this.service.create(dto, customer?.id);
  }

  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({
    summary:
      'List orders (brand / branch / status filters, pagination); a guest Bearer token restricts the list to that customer',
  })
  @ApiOkResponse({ type: OrderPage })
  list(
    @Query() query: OrderQueryDto,
    @CurrentCustomer() customer?: AuthenticatedCustomer,
  ): Promise<OrderPage> {
    return this.service.list(query, customer?.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get an order by id' })
  @ApiOkResponse({ type: OrderEntity })
  getById(@Param('id', ParseUUIDPipe) id: string): Promise<OrderEntity> {
    return this.service.getById(id);
  }

  @Patch(':id/status')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Change order status (operator / POS / kitchen); validated against the state machine',
  })
  @ApiOkResponse({ type: OrderEntity })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateOrderStatusDto,
  ): Promise<OrderEntity> {
    return this.service.updateStatus(id, dto);
  }
}
