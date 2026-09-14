import {
  Body,
  Controller,
  Get,
  GoneException,
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
  ApiGoneResponse,
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
import { KitchenJwtAuthGuard } from '../kitchen/guards/kitchen-jwt-auth.guard';
import { CurrentKitchenTerminal } from '../kitchen/decorators/current-kitchen-terminal.decorator';
import { AuthenticatedKitchenTerminal } from '../kitchen/kitchen.types';
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
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiUnauthorizedResponse({ description: 'Customer access token required' })
  @ApiOperation({
    summary:
      'List the authenticated customer own orders with filters and pagination',
  })
  @ApiOkResponse({ type: OrderPage })
  list(
    @Query() query: OrderQueryDto,
    @CurrentCustomer() customer: AuthenticatedCustomer,
  ): Promise<OrderPage> {
    return this.service.list(query, customer.id);
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
  @UseGuards(KitchenJwtAuthGuard)
  @ApiBearerAuth()
  @ApiUnauthorizedResponse({ description: 'Valid active kitchen terminal required' })
  @ApiOperation({ summary: 'SSE stream of order events for KDS by branch' })
  streamKdsOrders(
    @CurrentKitchenTerminal() terminal: AuthenticatedKitchenTerminal,
  ): Observable<MessageEvent> {
    return this.service.getKdsStream(terminal.branchId);
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiUnauthorizedResponse({ description: 'Customer access token required' })
  @ApiOperation({ summary: 'Get an authenticated customer own order by id' })
  @ApiOkResponse({ type: OrderEntity })
  getById(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentCustomer() customer: AuthenticatedCustomer,
  ): Promise<OrderEntity> {
    return this.service.getById(id, customer.id);
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
  @ApiOperation({
    summary: 'Retired: use authenticated kitchen or courier status endpoints',
    deprecated: true,
  })
  @ApiGoneResponse({ description: 'LEGACY_STATUS_ENDPOINT_DISABLED' })
  updateStatus(): never {
    // No staff authorization contract exists for this unrestricted legacy route.
    throw new GoneException({
      statusCode: 410,
      code: 'LEGACY_STATUS_ENDPOINT_DISABLED',
      message: 'Use the authenticated kitchen or courier status endpoint',
    });
  }
}
