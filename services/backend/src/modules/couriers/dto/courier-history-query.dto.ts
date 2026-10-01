import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsISO8601, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../menu/dto/pagination-query.dto';

/**
 * Query of GET /couriers/orders/history — the authenticated courier's own
 * completed/cancelled deliveries. Identity (courierId, branchId) comes from
 * the JWT; only date bounds and pagination are accepted here.
 */
export class CourierHistoryQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({
    description: 'Lower bound for completedAt (inclusive), ISO 8601',
    example: '2026-09-01T00:00:00Z',
  })
  @IsOptional()
  @IsISO8601()
  from?: string;

  @ApiPropertyOptional({
    description: 'Upper bound for completedAt (inclusive), ISO 8601',
    example: '2026-10-01T23:59:59Z',
  })
  @IsOptional()
  @IsISO8601()
  to?: string;
}
