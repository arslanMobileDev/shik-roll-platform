import { ApiProperty } from '@nestjs/swagger';
import { IsJWT } from 'class-validator';

export class ConfirmDeletionDto {
  @ApiProperty({
    description:
      'One-shot token from POST /customers/me/deletion-request (5 minute TTL)',
  })
  @IsJWT()
  deletionToken!: string;
}
