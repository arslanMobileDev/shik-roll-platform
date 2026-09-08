import { Controller, Get, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PromotionFeedQueryDto } from './dto/promotion-feed-query.dto';
import { PromotionFeedResponseDto } from './entities/loyalty.entities';
import { LoyaltyService } from './loyalty.service';

@ApiTags('promotions')
@Controller('promotions')
export class PromotionsController {
  constructor(private readonly service: LoyaltyService) {}

  /**
   * Active promotion campaigns of the brand (ADR-1614): only ACTIVE rows with
   * starts_at <= now < ends_at, ordered priority DESC, starts_at DESC —
   * feeds the mobile app carousel.
   */
  @Get('feed')
  @ApiOperation({ summary: 'Active promotion campaigns of the brand (mobile app carousel)' })
  @ApiOkResponse({ type: PromotionFeedResponseDto })
  getFeed(@Query() query: PromotionFeedQueryDto): Promise<PromotionFeedResponseDto> {
    return this.service.getPromotionFeed(query.brandId);
  }
}
