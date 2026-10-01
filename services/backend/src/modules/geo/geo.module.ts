import { Module } from '@nestjs/common';
import { GeoService } from './geo.service';

/**
 * Geo bounded context. Currently only exposes GeoService for address
 * geocoding; kept as its own module so future map-related helpers
 * (routing, distance) can live next to it.
 */
@Module({
  providers: [GeoService],
  exports: [GeoService],
})
export class GeoModule {}
