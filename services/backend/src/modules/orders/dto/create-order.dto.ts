import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { OrderType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class CreateOrderItemModifierDto {
  @ApiProperty({ description: 'Modifier (modifiers table) id' })
  @IsUUID()
  modifierItemId!: string;

  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  quantity?: number = 1;
}

export class CreateOrderItemDto {
  @ApiProperty({ description: 'Menu item (products table) id' })
  @IsUUID()
  menuItemId!: string;

  @ApiProperty({ minimum: 1 })
  @IsInt()
  @Min(1)
  quantity!: number;

  @ApiPropertyOptional({ description: 'Kitchen / line comment' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  comment?: string;

  @ApiPropertyOptional({ type: [CreateOrderItemModifierDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemModifierDto)
  modifiers?: CreateOrderItemModifierDto[];
}

export class CreateOrderDto {
  @ApiProperty({ enum: OrderType })
  @IsEnum(OrderType)
  type!: OrderType;

  @ApiProperty({ description: 'Brand the order belongs to' })
  @IsUUID()
  brandId!: string;

  @ApiProperty({ description: 'Branch the order is placed at' })
  @IsUUID()
  branchId!: string;

  @ApiPropertyOptional({ description: 'Table number (DINE_IN)' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  tableNumber?: string;

  @ApiPropertyOptional({ description: 'Delivery address (DELIVERY)' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  deliveryAddress?: string;

  @ApiPropertyOptional({ description: 'Order-level comment' })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  comment?: string;

  @ApiProperty({ type: [CreateOrderItemDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemDto)
  items!: CreateOrderItemDto[];
}
