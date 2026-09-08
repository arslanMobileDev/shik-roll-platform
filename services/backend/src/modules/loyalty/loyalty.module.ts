import { Module } from '@nestjs/common';
import { LoyaltyController } from './loyalty.controller';
import { LoyaltyService } from './loyalty.service';
import { PromotionsController } from './promotions.controller';

/**
 * Loyalty bounded context (ADR-1614): bonus balance and ledger, promotion
 * campaign feed. LoyaltyService is exported for the orders and queues
 * modules (checkout spend, cashback on COMPLETED, refund on CANCELLED).
 */
@Module({
  controllers: [LoyaltyController, PromotionsController],
  providers: [LoyaltyService],
  exports: [LoyaltyService],
})
export class LoyaltyModule {}
