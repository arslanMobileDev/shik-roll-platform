import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import {
  AuthenticatedKitchenTerminal,
  RequestWithKitchen,
} from '../kitchen.types';

/**
 * Reads the kitchen terminal identity attached by KitchenJwtAuthGuard. Used
 * by guarded kitchen routes so handlers never trust client-supplied
 * terminalId/branchId (ADR-1618).
 */
export const CurrentKitchenTerminal = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedKitchenTerminal => {
    const request = ctx.switchToHttp().getRequest<RequestWithKitchen>();
    return request.kitchenTerminal!;
  },
);
