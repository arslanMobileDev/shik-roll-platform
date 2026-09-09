import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Sse,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { Observable } from 'rxjs';
import { KitchenService } from './kitchen.service';
import { KitchenEventsService } from './kitchen-events.service';
import { KitchenPinAuthDto } from './dto/kitchen-auth.dto';
import { UpdateKitchenOrderStatusDto } from './dto/kitchen-order-status.dto';
import { KitchenJwtAuthGuard } from './guards/kitchen-jwt-auth.guard';
import { CurrentKitchenTerminal } from './decorators/current-kitchen-terminal.decorator';
import { AuthenticatedKitchenTerminal } from './kitchen.types';

@ApiTags('kitchen')
@Controller('kitchen')
export class KitchenController {
  constructor(
    private readonly kitchenService: KitchenService,
    private readonly eventsService: KitchenEventsService,
  ) {}

  /** Public entry point: issues the terminal JWT consumed by the routes below. */
  @Post('auth/pin')
  @ApiOperation({ summary: 'Authenticate a kitchen terminal by code and PIN' })
  async authPin(@Body() dto: KitchenPinAuthDto) {
    return this.kitchenService.authenticateByPin(dto);
  }

  /**
   * ADR-1618: the branch board snapshot. Branch identity comes from the
   * verified kitchen JWT only — a client-supplied branchId is never trusted.
   */
  @Get('orders/active')
  @UseGuards(KitchenJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Active kitchen board snapshot of the terminal branch' })
  @ApiUnauthorizedResponse({
    description: 'UNAUTHORIZED / TOKEN_INVALID / TERMINAL_INACTIVE',
  })
  async getActiveOrders(
    @CurrentKitchenTerminal() terminal: AuthenticatedKitchenTerminal,
  ) {
    return this.eventsService.getBoardSnapshot(terminal.branchId);
  }

  /**
   * Kitchen transitions: NEW/CONFIRMED -> COOKING -> READY with
   * optimistic concurrency (expectedVersion). terminalId/branchId are read
   * from the JWT, never from body or query.
   */
  @Patch('orders/:orderId/status')
  @UseGuards(KitchenJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Kitchen-driven order status transition' })
  @ApiUnauthorizedResponse({
    description: 'UNAUTHORIZED / TOKEN_INVALID / TERMINAL_INACTIVE',
  })
  async updateOrderStatus(
    @CurrentKitchenTerminal() terminal: AuthenticatedKitchenTerminal,
    @Param('orderId') orderId: string,
    @Body() dto: UpdateKitchenOrderStatusDto,
  ) {
    return this.kitchenService.updateOrderStatus(terminal, orderId, dto);
  }

  /**
   * ADR-1618 realtime contract: branch-scoped SSE with heartbeats. The first
   * board state comes from GET /kitchen/orders/active; this stream then
   * delivers upsert/remove events the client deduplicates by orderVersion.
   */
  @Sse('stream')
  @UseGuards(KitchenJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'SSE stream of kitchen order events' })
  @ApiUnauthorizedResponse({
    description: 'UNAUTHORIZED / TOKEN_INVALID / TERMINAL_INACTIVE',
  })
  streamOrders(
    @CurrentKitchenTerminal() terminal: AuthenticatedKitchenTerminal,
  ): Observable<MessageEvent> {
    return this.eventsService.getStream(terminal.branchId);
  }
}
