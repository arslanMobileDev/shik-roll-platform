import { Module } from '@nestjs/common';
import { CouriersEventsService } from './couriers-events.service';

/** Shared singleton streams without importing courier business dependencies. */
@Module({
  providers: [CouriersEventsService],
  exports: [CouriersEventsService],
})
export class CouriersEventsModule {}
