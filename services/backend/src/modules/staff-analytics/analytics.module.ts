import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { StaffAnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
@Module({
  imports: [PrismaModule],
  controllers: [StaffAnalyticsController],
  providers: [AnalyticsService],
})
export class AnalyticsModule {}
