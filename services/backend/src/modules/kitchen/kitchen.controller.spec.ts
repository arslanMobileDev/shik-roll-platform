import 'reflect-metadata';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { KitchenController } from './kitchen.controller';
import { KitchenJwtAuthGuard } from './guards/kitchen-jwt-auth.guard';
import { AuthenticatedKitchenTerminal } from './kitchen.types';

function guardsOf(handler: object): unknown[] {
  return Reflect.getMetadata(GUARDS_METADATA, handler) ?? [];
}

const TERMINAL: AuthenticatedKitchenTerminal = {
  id: 'terminal-1',
  code: 'KDS-01',
  name: 'Kitchen Terminal 1',
  branchId: 'branch-1',
  role: 'KITCHEN',
};

describe('KitchenController auth wiring', () => {
  it('protects GET /kitchen/orders/active with KitchenJwtAuthGuard', () => {
    expect(guardsOf(KitchenController.prototype.getActiveOrders)).toContain(
      KitchenJwtAuthGuard,
    );
  });

  it('protects PATCH /kitchen/orders/:orderId/status with KitchenJwtAuthGuard', () => {
    expect(guardsOf(KitchenController.prototype.updateOrderStatus)).toContain(
      KitchenJwtAuthGuard,
    );
  });

  it('protects the kitchen SSE stream with KitchenJwtAuthGuard', () => {
    expect(guardsOf(KitchenController.prototype.streamOrders)).toContain(
      KitchenJwtAuthGuard,
    );
  });

  it('leaves POST /kitchen/auth/pin public', () => {
    expect(guardsOf(KitchenController.prototype.authPin)).not.toContain(
      KitchenJwtAuthGuard,
    );
  });

  it('scopes the board snapshot to the JWT branch identity', async () => {
    const eventsService = {
      getBoardSnapshot: jest.fn().mockResolvedValue({ serverTime: '', orders: [] }),
    };
    const controller = new KitchenController({} as never, eventsService as never);

    await controller.getActiveOrders(TERMINAL);

    // Identity comes from the guard-verified token only.
    expect(eventsService.getBoardSnapshot).toHaveBeenCalledWith('branch-1');
  });

  it('scopes the SSE stream to the JWT branch identity', () => {
    const eventsService = { getStream: jest.fn().mockReturnValue('stream') };
    const controller = new KitchenController({} as never, eventsService as never);

    controller.streamOrders(TERMINAL);

    expect(eventsService.getStream).toHaveBeenCalledWith('branch-1');
  });

  it('passes JWT identity and DTO to the service on transitions', async () => {
    const kitchenService = {
      updateOrderStatus: jest.fn().mockResolvedValue({ id: 'order-1' }),
    };
    const controller = new KitchenController(kitchenService as never, {} as never);
    const dto = { status: 'COOKING' as const, expectedVersion: 3 };

    await controller.updateOrderStatus(TERMINAL, 'order-1', dto);

    expect(kitchenService.updateOrderStatus).toHaveBeenCalledWith(
      TERMINAL,
      'order-1',
      dto,
    );
  });
});
