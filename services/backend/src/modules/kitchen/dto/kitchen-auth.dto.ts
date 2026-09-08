import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches } from 'class-validator';

/**
 * Terminal sign-in (ADR-1618): shared device identity, never a personal one.
 * The PIN is exactly 4 digits; branch/terminal ids are never accepted from
 * the client — the code resolves them server-side.
 */
export class KitchenPinAuthDto {
  @ApiProperty({ example: 'KDS-01', description: 'Kitchen terminal code' })
  @IsString()
  @IsNotEmpty()
  terminalCode!: string;

  @ApiProperty({ example: '1234', description: '4-digit terminal PIN' })
  @IsString()
  @Matches(/^\d{4}$/, { message: 'pin must be exactly 4 digits' })
  pin!: string;
}
