import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

/**
 * Query of GET /promotions/feed (ADR-1614): the feed is always scoped to the
 * requesting brand ("current brand" of the mobile app).
 */
export class PromotionFeedQueryDto {
  @ApiProperty({ description: 'Brand whose active campaigns are returned' })
  @IsUUID()
  brandId!: string;
}
