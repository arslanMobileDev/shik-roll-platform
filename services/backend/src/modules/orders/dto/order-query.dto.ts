import { ApiPropertyOptional } from '@nestjs/swagger';
import { OrderStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { PaginationQueryDto } from '../../menu/dto/pagination-query.dto';

export class OrderQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filter orders by brand' })
  @IsOptional()
  @IsUUID()
  brandId?: string;

  @ApiPropertyOptional({ description: 'Filter orders by branch' })
  @IsOptional()
  @IsUUID()
  branchId?: string;

  @ApiPropertyOptional({ enum: OrderStatus, description: 'Filter by order status' })
  @IsOptional()
  @IsEnum(OrderStatus)
  status?: OrderStatus;
}
