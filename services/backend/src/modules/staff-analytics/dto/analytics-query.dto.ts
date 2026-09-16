import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsUUID, Matches } from 'class-validator';

export enum RevenuePeriod {
  TODAY = 'today', YESTERDAY = 'yesterday', WEEK = 'week',
  MONTH = 'month', YEAR = 'year', CUSTOM = 'custom',
}
export class AnalyticsQueryDto {
  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional() @IsUUID() branchId?: string;

  @ApiPropertyOptional({ enum: RevenuePeriod, default: RevenuePeriod.TODAY })
  @IsOptional() @IsEnum(RevenuePeriod) period?: RevenuePeriod;

  @ApiPropertyOptional({ format: 'date', description: 'MSK date, custom only, inclusive' })
  @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) dateFrom?: string;

  @ApiPropertyOptional({ format: 'date', description: 'MSK date, custom only, inclusive' })
  @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) dateTo?: string;
}
