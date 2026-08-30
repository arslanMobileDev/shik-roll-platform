import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { OrderStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class UpdateOrderStatusDto {
  @ApiProperty({ enum: OrderStatus, description: 'Target status of the transition' })
  @IsEnum(OrderStatus)
  status!: OrderStatus;

  @ApiPropertyOptional({ description: 'Actor performing the transition (user id)' })
  @IsOptional()
  @IsUUID()
  changedBy?: string;

  @ApiPropertyOptional({ description: 'Reason, e.g. cancellation cause' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
