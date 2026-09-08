import { Body, Controller, Get, Post, Query, Sse, UseGuards } from '@nestjs/common';
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
import { CourierJwtAuthGuard } from './guards/courier-jwt-auth.guard';

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

  @Get('orders/active')
  @UseGuards(CourierJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List active delivery orders' })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  async getActiveOrders(
    @Query('branchId') branchId?: string,
    @Query('courierId') courierId?: string,
  ) {
    return this.couriersService.getActiveOrders(branchId, courierId);
  }

  @Sse('stream')
  @UseGuards(CourierJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'SSE stream for live order updates' })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  streamOrders(@Query('branchId') branchId?: string): Observable<MessageEvent> {
    return this.eventsService.getOrderStream(branchId);
  }
}
