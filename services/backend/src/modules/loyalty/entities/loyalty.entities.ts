import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BonusTransactionType } from '@prisma/client';

/**
 * API contracts of the loyalty bounded context (ADR-1614). Wire format is
 * snake_case; money would be decimal strings, bonus points are JSON integers.
 */

export class BonusTransactionDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ enum: BonusTransactionType })
  type!: BonusTransactionType;

  @ApiProperty({ description: 'Signed points: EARN/REFUND > 0; SPEND/EXPIRE < 0' })
  points!: number;

  @ApiProperty()
  balance_after!: number;

  @ApiPropertyOptional({ type: String, nullable: true })
  order_id!: string | null;

  @ApiProperty()
  created_at!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  expires_at!: string | null;
}

export class LoyaltyBalancePaginationDto {
  @ApiProperty()
  page!: number;

  @ApiProperty()
  page_size!: number;

  @ApiProperty()
  total!: number;

  @ApiProperty()
  total_pages!: number;
}

export class LoyaltyBalanceResponseDto {
  @ApiProperty({ description: 'Current bonus balance (1 point = 1 RUB)' })
  balance!: number;

  @ApiProperty({ description: 'Cashback rate in percent, 0..100' })
  cashback_rate!: number;

  @ApiProperty({ type: [BonusTransactionDto] })
  transactions!: BonusTransactionDto[];

  @ApiProperty({ type: LoyaltyBalancePaginationDto })
  pagination!: LoyaltyBalancePaginationDto;
}

export class PromotionFeedItemDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  title!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  description!: string | null;

  @ApiProperty()
  banner_url!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  action_url!: string | null;

  @ApiProperty()
  starts_at!: string;

  @ApiProperty()
  ends_at!: string;
}

export class PromotionFeedResponseDto {
  @ApiProperty({ type: [PromotionFeedItemDto] })
  items!: PromotionFeedItemDto[];
}
