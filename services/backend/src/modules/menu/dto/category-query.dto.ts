import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';
import { PaginationQueryDto } from './pagination-query.dto';

export class CategoryQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filter categories by menu' })
  @IsOptional()
  @IsUUID()
  menuId?: string;

  @ApiPropertyOptional({ description: 'Filter categories by brand' })
  @IsOptional()
  @IsUUID()
  brandId?: string;
}
