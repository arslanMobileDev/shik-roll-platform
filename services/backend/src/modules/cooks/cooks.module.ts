import { Module } from '@nestjs/common';
import { CooksController, StaffCooksController } from './cooks.controller';
import { CooksService } from './cooks.service';
import { CookSessionService } from './cook-session.service';
import { CookStatisticsService } from './cook-statistics.service';
import { CookJwtAuthGuard } from './cook-jwt-auth.guard';
import { OptionalCookGuard } from './optional-cook.guard';
@Module({ controllers: [CooksController, StaffCooksController], providers: [CooksService, CookSessionService, CookStatisticsService, CookJwtAuthGuard, OptionalCookGuard], exports: [CookSessionService, OptionalCookGuard] })
export class CooksModule {
}
