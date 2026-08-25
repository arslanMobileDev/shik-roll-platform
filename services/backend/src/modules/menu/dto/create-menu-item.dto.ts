import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class MenuItemIngredientInputDto {
  @ApiProperty({ description: 'Ingredient UUID (brand catalog)' })
  @IsUUID()
  ingredientId!: string;

  @ApiPropertyOptional({ description: 'Quantity in the given unit' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 3 })
  @Min(0)
  quantity?: number;

  @ApiPropertyOptional({ description: 'Unit override (g | ml | pcs)' })
  @IsOptional()
  @IsString()
  @MaxLength(16)
  unit?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isOptional?: boolean;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;
}

export class CreateMenuItemDto {
  @ApiProperty({ description: 'Category the item belongs to' })
  @IsUUID()
  categoryId!: string;

  @ApiProperty({ description: 'SKU, unique within the brand' })
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  sku!: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  name!: string;

  @ApiPropertyOptional({
    description: 'URL slug, unique within the brand; generated from the name when omitted',
  })
  @IsOptional()
  @IsString()
  @MaxLength(180)
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, {
    message: 'slug must be kebab-case (lowercase letters, digits, dashes)',
  })
  slug?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  description?: string;

  @ApiProperty({ description: 'Base price in RUB (branch overrides via PATCH price)' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  basePrice!: number;

  @ApiPropertyOptional({ default: 'RUB' })
  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @ApiPropertyOptional({ description: 'Weight in grams' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 3 })
  @Min(0)
  weight?: number;

  @ApiPropertyOptional({ description: 'Calories, kcal' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000)
  calories?: number;

  @ApiPropertyOptional({ description: 'Preparation time, minutes' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1440)
  preparationTime?: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isFeatured?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({ type: [MenuItemIngredientInputDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => MenuItemIngredientInputDto)
  ingredients?: MenuItemIngredientInputDto[];

  @ApiPropertyOptional({
    type: [String],
    description: 'Modifier group UUIDs attached to the item',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('4', { each: true })
  modifierGroupIds?: string[];

  @ApiPropertyOptional({
    type: [String],
    description: 'Certification tag UUIDs (e.g. HALAL) attached to the item',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('4', { each: true })
  certificationTagIds?: string[];
}
