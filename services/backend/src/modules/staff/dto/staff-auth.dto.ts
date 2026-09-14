import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class StaffPinAuthDto {
  @ApiProperty({ example: '+79991234567' })
  @IsString()
  @MaxLength(20)
  phone!: string;

  @ApiProperty({ example: '1234', minLength: 4, maxLength: 8 })
  @IsString()
  @MinLength(4)
  @MaxLength(8)
  @Matches(/^\d+$/, { message: 'PIN must contain digits only' })
  pin!: string;
}
