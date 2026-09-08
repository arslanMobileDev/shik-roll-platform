import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthenticatedCourier, RequestWithCourier } from '../couriers.types';

/**
 * Reads the courier identity attached by CourierJwtAuthGuard. Used by guarded
 * courier routes so handlers never trust client-supplied courierId/branchId
 * (ADR-1617).
 */
export const CurrentCourier = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedCourier => {
    const request = ctx.switchToHttp().getRequest<RequestWithCourier>();
    return request.courier!;
  },
);
