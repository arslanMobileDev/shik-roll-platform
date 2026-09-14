import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthenticatedStaff, RequestWithStaff } from '../staff.types';

/**
 * Injects the staff actor attached by StaffJwtAuthGuard. The guard must
 * be present on the route (or its controller) for this to be populated.
 */
export const CurrentStaff = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedStaff => {
    const request = ctx.switchToHttp().getRequest<RequestWithStaff>();
    if (!request.staff) {
      throw new Error('CurrentStaff used without StaffJwtAuthGuard');
    }
    return request.staff;
  },
);
