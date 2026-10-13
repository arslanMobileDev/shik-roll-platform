import { Module } from '@nestjs/common';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';

/**
 * Customer account lifecycle (Apple-required self-service deletion).
 *
 * A separate module rather than extra routes on AuthController: the deletion
 * flow needs LoyaltyService (bonus burn), and hanging it off AuthModule would
 * drag the loyalty context into every consumer of auth. AuthModule imports
 * CustomersService the other way, for the restore branch of the OTP login.
 */
@Module({
  imports: [LoyaltyModule],
  controllers: [CustomersController],
  providers: [CustomersService],
  exports: [CustomersService],
})
export class CustomersModule {}
