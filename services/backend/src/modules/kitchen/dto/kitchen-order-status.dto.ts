import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';

/**
 * Kitchen-driven order transition (ADR-1618): the terminal owns
 * NEW/CONFIRMED -> COOKING and COOKING -> READY only. `branchId`/`terminalId`
 * are never accepted from the client — they come from the verified kitchen
 * JWT. `cookId`/`shiftId` are audit metadata, not an authorization input.
 */
export class UpdateKitchenOrderStatusDto {
  @ApiProperty({ enum: ['COOKING', 'READY'], example: 'COOKING' })
  @IsIn(['COOKING', 'READY'])
  status!: 'COOKING' | 'READY';

  @ApiProperty({
    example: 3,
    description:
      'Optimistic concurrency: the order version the terminal based its decision on',
  })
  @IsInt()
  @Min(1)
  expectedVersion!: number;

  @ApiPropertyOptional({
    description: 'Audit metadata: deprecated; ignored, use X-Cook-Authorization',
  })
  @IsOptional()
  @IsString()
  cookId?: string;

  @ApiPropertyOptional({
    description: 'Audit metadata: deprecated; ignored, use X-Cook-Authorization',
  })
  @IsOptional()
  @IsString()
  shiftId?: string;
}
