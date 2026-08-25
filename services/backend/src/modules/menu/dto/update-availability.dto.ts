import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsUUID } from 'class-validator';

export class UpdateAvailabilityDto {
  @ApiProperty({ description: 'Branch the availability flag applies to' })
  @IsUUID()
  branchId!: string;

  @ApiProperty({ description: 'Whether the item is sellable at the branch' })
  @IsBoolean()
  isAvailable!: boolean;
}
