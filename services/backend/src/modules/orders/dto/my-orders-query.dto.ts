import { ApiPropertyOptional } from '@nestjs/swagger';
import { OrderStatus } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../menu/dto/pagination-query.dto';

/**
 * Query of GET /orders/my — the authenticated guest's own order history.
 * Pagination only (+ optional status filter); brand/branch scoping does not
 * apply to a personal history, and the sort is fixed: newest first.
 */
export class MyOrdersQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: OrderStatus, description: 'Filter by order status' })
  @IsOptional()
  @IsEnum(OrderStatus)
  status?: OrderStatus;
}
