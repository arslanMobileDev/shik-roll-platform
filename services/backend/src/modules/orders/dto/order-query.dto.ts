import { ApiPropertyOptional } from '@nestjs/swagger';
import { OrderStatus } from '@prisma/client';
import { Transform } from 'class-transformer';
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

  @ApiPropertyOptional({
    enum: OrderStatus,
    isArray: true,
    description: 'Filter by one or more statuses (CSV or repeated query parameter)',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    (Array.isArray(value) ? value : [value]).flatMap((item) =>
      String(item)
        .split(',')
        .map((status) => status.trim())
        .filter(Boolean),
    ),
  )
  @IsEnum(OrderStatus, { each: true })
  status?: OrderStatus[];
}
