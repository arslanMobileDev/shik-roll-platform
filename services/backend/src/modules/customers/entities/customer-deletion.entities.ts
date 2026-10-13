import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class DeletionRequestResponse {
  @ApiProperty({
    description: 'One-shot confirmation token for /customers/me/deletion-confirm',
  })
  deletionToken!: string;

  @ApiProperty({ description: 'Token lifetime in seconds', example: 300 })
  expiresInSeconds!: number;

  @ApiProperty({
    description: 'Bonus points that will be burned by the deletion',
    example: 120,
  })
  bonusBalance!: number;

  @ApiProperty({
    description:
      'False while an order is still in progress; deletion-confirm then answers 409 ACTIVE_ORDERS_EXIST',
  })
  canDelete!: boolean;

  @ApiPropertyOptional({
    enum: ['ACTIVE_ORDERS_EXIST'],
    description: 'Why the deletion is currently blocked',
  })
  blockedReason?: 'ACTIVE_ORDERS_EXIST';
}

export class ConfirmDeletionResponse {
  @ApiProperty({ example: true })
  deleted!: boolean;

  @ApiProperty({
    description:
      'Bonus points actually burned. May differ from the balance reported by ' +
      'deletion-request: that snapshot is a separate round-trip and can go stale.',
    example: 120,
  })
  expiredBonusPoints!: number;
}
