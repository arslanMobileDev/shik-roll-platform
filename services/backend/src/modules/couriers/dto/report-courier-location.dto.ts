import { ApiProperty } from '@nestjs/swagger';
import { IsISO8601, IsNumber, IsPositive, IsUUID, Max, Min } from 'class-validator';

/**
 * Single courier location fix (ADR-1617). Accepted only for the courier's own
 * ON_WAY order; courier/branch identity comes from the verified JWT.
 */
export class ReportCourierLocationDto {
  @ApiProperty({ description: 'Order the courier is currently delivering' })
  @IsUUID()
  orderId!: string;

  @ApiProperty({ minimum: -90, maximum: 90, example: 55.7893 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @ApiProperty({ minimum: -180, maximum: 180, example: 49.1221 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @ApiProperty({ description: 'GPS accuracy radius in meters, must be > 0', example: 12.5 })
  @IsNumber()
  @IsPositive()
  accuracyMeters!: number;

  @ApiProperty({ description: 'Client-side capture time (ISO 8601)', example: '2026-09-08T12:05:00.000Z' })
  @IsISO8601()
  capturedAt!: string;
}
