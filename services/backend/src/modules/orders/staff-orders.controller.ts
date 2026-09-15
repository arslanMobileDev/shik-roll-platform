import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { StaffJwtAuthGuard } from '../staff/guards/staff-jwt-auth.guard';
import { CurrentStaff } from '../staff/decorators/current-staff.decorator';
import { AuthenticatedStaff } from '../staff/staff.types';
import { OrderQueryDto } from './dto/order-query.dto';
import { OrderPage } from './entities/order.entity';
import { OrdersService } from './orders.service';

/**
 * Back-office orders journal (ADR-style: STAFF bounded context).
 *
 * Unlike GET /orders (customer-scoped), this endpoint returns every order
 * of the staff's brand. brandId always comes from the JWT — a staff token
 * can never read another brand's orders. branchId (optional) comes from
 * the query, so the UI can switch between branches of the same brand.
 *
 * Response shape is identical to /orders, so the Flutter client reuses
 * the existing OrdersPage.fromJson parser.
 */
@ApiTags('staff-orders')
@Controller('staff/orders')
@UseGuards(StaffJwtAuthGuard)
@ApiBearerAuth()
@ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
export class StaffOrdersController {
  constructor(private readonly service: OrdersService) {}

  @Get()
  @ApiOperation({
    summary: 'List orders of the staff brand (optional branchId filter)',
  })
  @ApiOkResponse({ type: OrderPage })
  list(
    @Query() query: OrderQueryDto,
    @CurrentStaff() staff: AuthenticatedStaff,
  ): Promise<OrderPage> {
    // Brand comes from the verified JWT — never from the query.
    const scoped: OrderQueryDto = { ...query, brandId: staff.brandId };
    return this.service.listAll(scoped);
  }
}
