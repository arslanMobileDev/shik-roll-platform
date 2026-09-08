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

  it('protects PATCH /couriers/orders/:orderId/status with CourierJwtAuthGuard', () => {
    expect(guardsOf(CouriersController.prototype.updateOrderStatus)).toContain(
      CourierJwtAuthGuard,
    );
  });

  it('protects POST /couriers/location with CourierJwtAuthGuard', () => {
    expect(guardsOf(CouriersController.prototype.reportLocation)).toContain(
      CourierJwtAuthGuard,
    );
  });

  it('leaves POST /couriers/auth/pin public', () => {
    expect(guardsOf(CouriersController.prototype.authPin)).not.toContain(
      CourierJwtAuthGuard,
    );
  });

  it('scopes the orders feed to the JWT branch and courier identity', async () => {
    const couriersService = { getActiveOrders: jest.fn().mockResolvedValue([]) };
    const controller = new CouriersController(couriersService as any, {} as any);
    const courier = {
      id: 'courier-1',
      phone: '+79991234567',
      branchId: 'branch-1',
      role: 'COURIER' as const,
    };

    await controller.getActiveOrders(courier);

    // Identity comes from the guard-verified token only.
    expect(couriersService.getActiveOrders).toHaveBeenCalledWith(
      'branch-1',
      'courier-1',
    );
  });

  it('scopes the SSE stream to the JWT branch', () => {
    const eventsService = {
      getOrderStream: jest.fn().mockReturnValue('stream'),
    };
    const controller = new CouriersController({} as any, eventsService as any);
    const courier = {
      id: 'courier-1',
      phone: '+79991234567',
      branchId: 'branch-9',
      role: 'COURIER' as const,
    };

    controller.streamOrders(courier);

    expect(eventsService.getOrderStream).toHaveBeenCalledWith('branch-9');
  });

  it('passes JWT identity and status DTO to the service on transitions', async () => {
    const couriersService = {
      updateCourierOrderStatus: jest.fn().mockResolvedValue({ id: 'order-1' }),
    };
    const controller = new CouriersController(couriersService as any, {} as any);
    const courier = {
      id: 'courier-1',
      phone: '+79991234567',
      branchId: 'branch-1',
      role: 'COURIER' as const,
    };

    await controller.updateOrderStatus(courier, 'order-1', {
      status: 'ON_WAY',
    });

    expect(couriersService.updateCourierOrderStatus).toHaveBeenCalledWith(
      courier,
      'order-1',
      { status: 'ON_WAY' },
    );
  });

  it('passes JWT identity and location DTO to the service on location reports', async () => {
    const couriersService = {
      reportCourierLocation: jest.fn().mockResolvedValue({ accepted: true }),
    };
    const controller = new CouriersController(couriersService as any, {} as any);
    const courier = {
      id: 'courier-1',
      phone: '+79991234567',
      branchId: 'branch-1',
      role: 'COURIER' as const,
    };
    const dto = {
      orderId: 'order-1',
      latitude: 55.78,
      longitude: 49.12,
      accuracyMeters: 10,
      capturedAt: new Date().toISOString(),
    };

    await controller.reportLocation(courier, dto);

    expect(couriersService.reportCourierLocation).toHaveBeenCalledWith(
      courier,
      dto,
    );
  });
});
