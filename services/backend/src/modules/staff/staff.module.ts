import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { StaffController } from './staff.controller';
import { StaffService } from './staff.service';
import { StaffJwtAuthGuard } from './guards/staff-jwt-auth.guard';

/**
 * Back-office staff bounded context: PIN login + JWT guard. Exports the
 * guard so menu/category controllers can protect mutating endpoints.
 */
@Module({
  imports: [PrismaModule],
  controllers: [StaffController],
  providers: [StaffService, StaffJwtAuthGuard],
  exports: [StaffService, StaffJwtAuthGuard],
})
export class StaffModule {}
