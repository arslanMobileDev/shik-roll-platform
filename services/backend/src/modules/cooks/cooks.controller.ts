import { CookRequest } from './cooks.dto';
import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CookTerminalAuthGuard, CookStaffAuthGuard } from './cook-endpoint-auth.guards';
import { CurrentStaff } from '../staff/decorators/current-staff.decorator';
import { AuthenticatedStaff } from '../staff/staff.types';
import { AnalyticsQueryDto, RevenuePeriod } from '../staff-analytics/dto/analytics-query.dto';
import { CookJwtAuthGuard } from './cook-jwt-auth.guard';
import { CooksService } from './cooks.service';
import { CookStatisticsService } from './cook-statistics.service';
import { CookBranchDto, CookLoginDto, CookStatsDto, CreateCookDto, UpdateCookDto } from './cooks.dto';
@ApiTags('cooks')
@ApiBearerAuth()
@Controller('cooks')
export class CooksController {
    constructor(private readonly cooks: CooksService, private readonly stats: CookStatisticsService) { }
    @Post('auth/pin')
    @UseGuards(CookTerminalAuthGuard)
    login(
    @Req()
    req: CookRequest,
    @Body()
    dto: CookLoginDto) { return this.cooks.login(req.kitchenTerminal, dto); }
    @Post('auth/logout')
    @UseGuards(CookJwtAuthGuard)
    logout(
    @Req()
    req: CookRequest) { return this.cooks.logout(req.cook); }
    @Get('me')
    @UseGuards(CookJwtAuthGuard)
    me(
    @Req()
    req: CookRequest) { return this.cooks.me(req.cook); }
    @Get('me/stats')
    @UseGuards(CookJwtAuthGuard)
    statsMe(
    @Req()
    req: CookRequest,
    @Query()
    query: CookStatsDto) { return this.stats.personal(req.cook, (query.period ?? 'today') as RevenuePeriod); }
}
@ApiTags('staff-cooks')
@ApiBearerAuth()
@UseGuards(CookStaffAuthGuard)
@Controller('staff')
export class StaffCooksController {
    constructor(private readonly cooks: CooksService, private readonly stats: CookStatisticsService) { }
    @Get('cooks')
    list(
    @CurrentStaff()
    staff: AuthenticatedStaff,
    @Query()
    q: CookBranchDto) { return this.cooks.list(staff, q.branchId); }
    @Post('cooks')
    create(
    @CurrentStaff()
    staff: AuthenticatedStaff,
    @Body()
    dto: CreateCookDto) { return this.cooks.create(staff, dto); }
    @Patch('cooks/:id')
    update(
    @CurrentStaff()
    staff: AuthenticatedStaff,
    @Param('id', ParseUUIDPipe)
    id: string,
    @Body()
    dto: UpdateCookDto) { return this.cooks.update(staff, id, dto); }
    @Delete('cooks/:id')
    remove(
    @CurrentStaff()
    staff: AuthenticatedStaff,
    @Param('id', ParseUUIDPipe)
    id: string) { return this.cooks.update(staff, id, { isActive: false }); }
    @Get('shifts')
    shifts(
    @CurrentStaff()
    staff: AuthenticatedStaff,
    @Query()
    q: AnalyticsQueryDto) { return this.stats.shifts(staff, q); }
    @Get('analytics/cooks')
    top(
    @CurrentStaff()
    staff: AuthenticatedStaff,
    @Query()
    q: AnalyticsQueryDto) { return this.stats.top(staff, q); }
}
