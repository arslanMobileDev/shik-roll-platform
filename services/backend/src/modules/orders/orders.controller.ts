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
} from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
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
  @ApiOperation({ summary: 'Create an order from POS or the mobile app' })
  @ApiCreatedResponse({ type: OrderEntity })
  create(@Body() dto: CreateOrderDto): Promise<OrderEntity> {
    return this.service.create(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List orders (brand / branch / status filters, pagination)' })
  @ApiOkResponse({ type: OrderPage })
  list(@Query() query: OrderQueryDto): Promise<OrderPage> {
    return this.service.list(query);
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
