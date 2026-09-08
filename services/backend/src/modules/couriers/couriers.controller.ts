import {
  Body,
  Controller,
  Get,
  HttpCode,
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
import { CouriersService } from './couriers.service';
import { CouriersEventsService } from './couriers-events.service';
import { CourierPinAuthDto } from './dto/courier-auth.dto';
import { UpdateCourierOrderStatusDto } from './dto/update-courier-order-status.dto';
import { ReportCourierLocationDto } from './dto/report-courier-location.dto';
import { CourierJwtAuthGuard } from './guards/courier-jwt-auth.guard';
import { CurrentCourier } from './decorators/current-courier.decorator';
import { AuthenticatedCourier } from './couriers.types';

@ApiTags('couriers')
@Controller('couriers')
export class CouriersController {
  constructor(
    private readonly couriersService: CouriersService,
    private readonly eventsService: CouriersEventsService,
  ) {}

  /** Public entry point: issues the courier JWT consumed by the routes below. */
  @Post('auth/pin')
  @ApiOperation({ summary: 'Authenticate courier by phone and PIN' })
  async authPin(@Body() dto: CourierPinAuthDto) {
    return this.couriersService.authenticateByPin(dto);
  }

  /**
   * ADR-1617: branch and courier identity come from the verified JWT only;
   * legacy branchId/courierId query params are ignored.
   */
  @Get('orders/active')
  @UseGuards(CourierJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List active delivery orders of the courier branch' })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  async getActiveOrders(@CurrentCourier() courier: AuthenticatedCourier) {
    return this.couriersService.getActiveOrders(courier.branchId, courier.id);
  }

  /**
   * ADR-1617 courier transitions: claim (READY), start (ON_WAY),
   * complete (COMPLETED). courierId/branchId are read from the JWT, never
   * from body or query.
   */
  @Patch('orders/:orderId/status')
  @UseGuards(CourierJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Courier-driven order status transition' })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  async updateOrderStatus(
    @CurrentCourier() courier: AuthenticatedCourier,
    @Param('orderId') orderId: string,
    @Body() dto: UpdateCourierOrderStatusDto,
  ) {
    return this.couriersService.updateCourierOrderStatus(courier, orderId, dto);
  }

  /**
   * ADR-1617 location intake: 202 Accepted when the fix belongs to the
   * courier's own ON_WAY order. Raw coordinates are never logged.
   */
  @Post('location')
  @HttpCode(202)
  @UseGuards(CourierJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Report courier location for the active delivery' })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  async reportLocation(
    @CurrentCourier() courier: AuthenticatedCourier,
    @Body() dto: ReportCourierLocationDto,
  ) {
    return this.couriersService.reportCourierLocation(courier, dto);
  }

  @Sse('stream')
  @UseGuards(CourierJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'SSE stream for live order updates' })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  streamOrders(
    @CurrentCourier() courier: AuthenticatedCourier,
  ): Observable<MessageEvent> {
    return this.eventsService.getOrderStream(courier.branchId);
  }
}
