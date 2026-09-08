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
  Sse,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { Observable } from 'rxjs';
import { AuthenticatedCustomer } from '../auth/auth.types';
import { CurrentCustomer } from '../auth/decorators/current-customer.decorator';
import { JwtAuthGuard, OptionalJwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateOrderDto } from './dto/create-order.dto';
import { MyOrdersQueryDto } from './dto/my-orders-query.dto';
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

  // Declared before @Get(':id') so the literal "my" is not captured by the
  // UUID parameter route.
  @Get('my')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      "Authenticated guest's own orders (mobile app history), newest first, paginated",
  })
  @ApiOkResponse({ type: OrderPage })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  listMine(
    @Query() query: MyOrdersQueryDto,
    @CurrentCustomer() customer: AuthenticatedCustomer,
  ): Promise<OrderPage> {
    return this.service.listMine(customer.id, query);
  }

  /**
   * KDS live stream (ADR-1620): SSE stream for kitchen orders filtered by branch.
   */
  @Sse('kds/stream')
  @ApiOperation({ summary: 'SSE stream of order events for KDS by branch' })
  streamKdsOrders(
    @Query('branchId') branchId: string,
  ): Observable<MessageEvent> {
    return this.service.getKdsStream(branchId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get an order by id' })
  @ApiOkResponse({ type: OrderEntity })
  getById(@Param('id', ParseUUIDPipe) id: string): Promise<OrderEntity> {
    return this.service.getById(id);
  }

  /**
   * Customer order tracking (ADR-1615): SSE stream of the order's status
   * changes. The first event is a snapshot of the current state, subsequent
   * events arrive on every status transition. Own orders only.
   */
  @Sse(':id/tracking-stream')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: "SSE stream of the guest's own order status updates (snapshot first, then live events)",
  })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  trackOrder(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentCustomer() customer: AuthenticatedCustomer,
  ): Promise<Observable<MessageEvent>> {
    return this.service.getTrackingStream(id, customer.id);
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
