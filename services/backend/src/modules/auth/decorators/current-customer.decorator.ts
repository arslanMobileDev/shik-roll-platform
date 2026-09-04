import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthenticatedCustomer, RequestWithCustomer } from '../auth.types';

/**
 * Injects the guest identity attached by JwtAuthGuard / OptionalJwtAuthGuard.
 * Undefined when the request is anonymous (optional guard, no token).
 */
export const CurrentCustomer = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedCustomer | undefined =>
    ctx.switchToHttp().getRequest<RequestWithCustomer>().customer,
);
