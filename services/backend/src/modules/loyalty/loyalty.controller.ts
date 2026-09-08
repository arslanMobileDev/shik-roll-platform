import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { AuthenticatedCustomer } from '../auth/auth.types';
import { CurrentCustomer } from '../auth/decorators/current-customer.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { LoyaltyBalanceQueryDto } from './dto/loyalty-balance-query.dto';
import { LoyaltyBalanceResponseDto } from './entities/loyalty.entities';
import { LoyaltyService } from './loyalty.service';

@ApiTags('loyalty')
@Controller('loyalty')
export class LoyaltyController {
  constructor(private readonly service: LoyaltyService) {}

  /**
   * Bonus balance of the authenticated guest (ADR-1614): balance, cashback
   * rate and a paginated ledger history (newest first). The balance is a
   * server-side projection — it is never accepted from or computed by the
   * mobile app.
   */
  @Get('balance')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: "Authenticated guest's bonus balance, cashback rate and transaction history",
  })
  @ApiOkResponse({ type: LoyaltyBalanceResponseDto })
  @ApiUnauthorizedResponse({ description: 'UNAUTHORIZED / TOKEN_INVALID' })
  getBalance(
    @Query() query: LoyaltyBalanceQueryDto,
    @CurrentCustomer() customer: AuthenticatedCustomer,
  ): Promise<LoyaltyBalanceResponseDto> {
    return this.service.getBalance(
      customer.id,
      query.page ?? 1,
      query.pageSize ?? 20,
    );
  }
}
