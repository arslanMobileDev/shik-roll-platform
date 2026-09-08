import { ApiProperty } from '@nestjs/swagger';
import { IsIn } from 'class-validator';

/**
 * Courier-driven order transition (ADR-1617). Identity fields (`courierId`,
 * `branchId`) are never accepted from the client — they come from the
 * verified courier JWT only.
 *
 *   READY     claim an unassigned READY order (atomic assign)
 *   ON_WAY    start the delivery of the courier's own READY order
 *   COMPLETED finish the courier's own ON_WAY delivery
 */
export class UpdateCourierOrderStatusDto {
  @ApiProperty({ enum: ['READY', 'ON_WAY', 'COMPLETED'], example: 'ON_WAY' })
  @IsIn(['READY', 'ON_WAY', 'COMPLETED'])
  status!: 'READY' | 'ON_WAY' | 'COMPLETED';
}
