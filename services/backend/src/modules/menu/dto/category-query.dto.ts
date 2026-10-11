import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsOptional, IsUUID } from 'class-validator';
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

  @ApiPropertyOptional({
    description:
      'Include deactivated categories — the back-office needs them to reactivate; ' +
      'the public catalog must not set this.',
  })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  includeInactive?: boolean;
}
