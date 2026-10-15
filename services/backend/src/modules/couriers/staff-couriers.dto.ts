import { Transform } from 'class-transformer';
import { IsBoolean, IsOptional, IsString, IsUUID, Matches, MaxLength, MinLength, ValidateIf } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export function normalizeCourierPhone(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const compact = value.replace(/[\s()-]/g, '');
  if (/^\d{10}$/.test(compact)) return '+7' + compact;
  if (/^[78]\d{10}$/.test(compact)) return '+7' + compact.slice(1);
  return compact;
}
const trimName = ({ value }: { value: unknown }) => typeof value === 'string' ? value.trim() : value;

// A query string carries booleans as text. Anything that is neither spelling is
// left untouched so @IsBoolean rejects it: `?includeDeleted=1` silently meaning
// "live couriers only" is the kind of misread that hides rows from the panel.
const toBoolean = ({ value }: { value: unknown }): unknown =>
  value === 'true' || value === true
    ? true
    : value === 'false' || value === false
      ? false
      : value;

export class CourierBranchQueryDto {
  @ApiProperty() @IsUUID() branchId!: string;

  @ApiPropertyOptional({
    description: 'Lists self-deleted couriers inside the restore window instead of live ones',
  })
  @IsOptional() @Transform(toBoolean) @IsBoolean()
  includeDeleted?: boolean;
}
export class CreateCourierDto {
  @ApiProperty() @Transform(trimName) @IsString() @MinLength(1) @MaxLength(100)
  name!: string;

  @ApiProperty() @Transform(({ value }) => normalizeCourierPhone(value)) @Matches(/^\+7\d{10}$/)
  phone!: string;

  @ApiProperty({ minLength: 4, maxLength: 8, writeOnly: true }) @Matches(/^\d{4,8}$/)
  pin!: string;

  @ApiProperty() @IsUUID() branchId!: string;
}
export class UpdateCourierDto {
  @ApiPropertyOptional() @ValidateIf((_, value) => value !== undefined)
  @Transform(trimName) @IsString() @MinLength(1) @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({ minLength: 4, maxLength: 8, writeOnly: true })
  @ValidateIf((_, value) => value !== undefined) @Matches(/^\d{4,8}$/)
  pin?: string;

  @ApiPropertyOptional() @ValidateIf((_, value) => value !== undefined) @IsBoolean()
  isActive?: boolean;
}
