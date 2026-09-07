import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class CourierPinAuthDto {
  @ApiProperty({ example: '+79991234567', description: 'Courier phone number' })
  @IsString()
  @IsNotEmpty()
  phone!: string;

  @ApiProperty({ example: '1234', description: '4-digit PIN' })
  @IsString()
  @IsNotEmpty()
  pin!: string;
}
