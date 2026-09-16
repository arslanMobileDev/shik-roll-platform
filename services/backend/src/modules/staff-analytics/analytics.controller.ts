import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags, ApiOperation } from '@nestjs/swagger';
import { StaffJwtAuthGuard } from '../staff/guards/staff-jwt-auth.guard';
import { CurrentStaff } from '../staff/decorators/current-staff.decorator';
import { AuthenticatedStaff } from '../staff/staff.types';
import { AnalyticsQueryDto } from './dto/analytics-query.dto';
import { RevenueResponse } from './entities/revenue-response.entity';
import { AnalyticsService } from './analytics.service';

@ApiTags('staff-analytics')
@ApiBearerAuth()
@UseGuards(StaffJwtAuthGuard)
@Controller('staff/analytics')
export class StaffAnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}
  @Get('revenue')
  @ApiOperation({ summary: 'Completed-order revenue for the verified staff brand, MSK calendar periods' })
  @ApiOkResponse({ type: RevenueResponse })
  revenue(@Query() query: AnalyticsQueryDto, @CurrentStaff() staff: AuthenticatedStaff) {
    return this.analytics.revenue(staff, query);
  }
}
