import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';
import { PaginationQueryDto } from './pagination-query.dto';

export class MenuQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filter menus by brand' })
  @IsOptional()
  @IsUUID()
  brandId?: string;

  @ApiPropertyOptional({
    description:
      'Filter menus by branch; brand-level default menus (branchId = null) are included',
  })
  @IsOptional()
  @IsUUID()
  branchId?: string;
}
