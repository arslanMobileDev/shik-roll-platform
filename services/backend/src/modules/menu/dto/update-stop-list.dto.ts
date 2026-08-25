import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class UpdateStopListDto {
  @ApiProperty({ description: 'Branch the stop list entry applies to' })
  @IsUUID()
  branchId!: string;

  @ApiProperty({ description: 'true — put the item on the stop list, false — remove it' })
  @IsBoolean()
  isActive!: boolean;

  @ApiPropertyOptional({ description: 'Reason for stopping sales' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
