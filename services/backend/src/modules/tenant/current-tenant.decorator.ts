import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { RequestWithTenant, TenantContext } from './tenant.types';

/**
 * Injects the tenant resolved by TenantMiddleware.
 *
 * Unlike @CurrentStaff this does NOT throw when absent — declaring no tenant is
 * a supported state (see TenantMiddleware). Callers that need one decide what
 * to do about `undefined`; today that is the PIN login services, which resolve
 * the owning tenant themselves when the client declared none.
 */
export const CurrentTenant = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): TenantContext | undefined =>
    ctx.switchToHttp().getRequest<RequestWithTenant>().tenant,
);
