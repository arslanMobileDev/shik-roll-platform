import { Body, Controller, Get, Post, Query, Sse } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Observable } from 'rxjs';
import { CouriersService } from './couriers.service';
import { CouriersEventsService } from './couriers-events.service';
import { CourierPinAuthDto } from './dto/courier-auth.dto';

@ApiTags('couriers')
@Controller('couriers')
export class CouriersController {
  constructor(
    private readonly couriersService: CouriersService,
    private readonly eventsService: CouriersEventsService,
  ) {}

  @Post('auth/pin')
  @ApiOperation({ summary: 'Authenticate courier by phone and PIN' })
  async authPin(@Body() dto: CourierPinAuthDto) {
    return this.couriersService.authenticateByPin(dto);
  }

  @Get('orders/active')
  @ApiOperation({ summary: 'List active delivery orders' })
  async getActiveOrders(
    @Query('branchId') branchId?: string,
    @Query('courierId') courierId?: string,
  ) {
    return this.couriersService.getActiveOrders(branchId, courierId);
  }

  @Sse('stream')
  @ApiOperation({ summary: 'SSE stream for live order updates' })
  streamOrders(@Query('branchId') branchId?: string): Observable<MessageEvent> {
    return this.eventsService.getOrderStream(branchId);
  }
}
