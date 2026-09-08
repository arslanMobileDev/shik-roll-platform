import 'reflect-metadata';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { CouriersController } from './couriers.controller';
import { CourierJwtAuthGuard } from './guards/courier-jwt-auth.guard';

function guardsOf(handler: object): unknown[] {
  return Reflect.getMetadata(GUARDS_METADATA, handler) ?? [];
}

describe('CouriersController auth wiring', () => {
  it('protects GET /couriers/orders/active with CourierJwtAuthGuard', () => {
    expect(guardsOf(CouriersController.prototype.getActiveOrders)).toContain(
      CourierJwtAuthGuard,
    );
  });

  it('protects the courier SSE stream with CourierJwtAuthGuard', () => {
    expect(guardsOf(CouriersController.prototype.streamOrders)).toContain(
      CourierJwtAuthGuard,
    );
  });

  it('leaves POST /couriers/auth/pin public', () => {
    expect(guardsOf(CouriersController.prototype.authPin)).not.toContain(
      CourierJwtAuthGuard,
    );
  });
});
