import { ApiPropertyOptional } from '@nestjs/swagger';
import { Expose, Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/**
 * Query of GET /loyalty/balance (ADR-1614): page >= 1, page_size = 1..100.
 * The wire parameter is snake_case `page_size`; it maps to the `pageSize`
 * property via class-transformer.
 */
export class LoyaltyBalanceQueryDto {
  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ name: 'page_size', default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Expose({ name: 'page_size' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize?: number = 20;
}
