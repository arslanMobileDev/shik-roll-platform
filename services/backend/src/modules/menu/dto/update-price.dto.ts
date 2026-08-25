import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString, IsUUID, Length, Min } from 'class-validator';

export class UpdatePriceDto {
  @ApiProperty({ description: 'Branch the price override applies to' })
  @IsUUID()
  branchId!: string;

  @ApiProperty({ description: 'New branch price in RUB', minimum: 0 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  price!: number;

  @ApiPropertyOptional({ default: 'RUB' })
  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;
}
