import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

/**
 * The PIN, re-entered, is what makes this call unforgeable.
 *
 * The customer flow mints a short-lived one-shot `deletionToken` for its second
 * step, because there a body flag like `{confirm: true}` would be something the
 * client could simply set. A courier already holds a secret the client cannot
 * fabricate — the PIN — and the server can check it with bcrypt, so the token
 * machinery (JWT type, TTL, replay surface) buys nothing here.
 */
export class DeleteCourierAccountDto {
  @ApiProperty({ example: '1234', description: 'Courier PIN, re-entered' })
  @IsString()
  @IsNotEmpty()
  pin!: string;
}
