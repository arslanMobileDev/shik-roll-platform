import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { PaginationQueryDto } from './pagination-query.dto';

const toBoolean = ({ value }: { value: unknown }): unknown =>
  value === 'true' || value === true
    ? true
    : value === 'false' || value === false
      ? false
      : value;

export class MenuItemQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Filter items by brand' })
  @IsOptional()
  @IsUUID()
  brandId?: string;

  @ApiPropertyOptional({
    description:
      'Branch context: resolves branch price override, availability and stop list',
  })
  @IsOptional()
  @IsUUID()
  branchId?: string;

  @ApiPropertyOptional({ description: 'Filter items by category' })
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @ApiPropertyOptional({
    description: 'Only items holding a valid HALAL certification tag',
  })
  @IsOptional()
  @Transform(toBoolean)
  @IsBoolean()
  isHalal?: boolean;

  @ApiPropertyOptional({
    description:
      'Excludes items that are unavailable or stop-listed for the given branchId',
  })
  @IsOptional()
  @Transform(toBoolean)
  @IsBoolean()
  availableOnly?: boolean;

  @ApiPropertyOptional({ description: 'Case-insensitive search by name, SKU or description' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;
}
