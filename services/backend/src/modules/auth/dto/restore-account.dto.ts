import { ApiProperty } from '@nestjs/swagger';
import { IsJWT } from 'class-validator';

export class RestoreAccountDto {
  @ApiProperty({
    description:
      'One-shot token returned as restoreToken by POST /auth/otp/verify when ' +
      'the phone belongs to a deleted account inside its freeze window',
  })
  @IsJWT()
  restoreToken!: string;
}
