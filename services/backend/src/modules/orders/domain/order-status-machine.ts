import { OrderStatus } from '@prisma/client';

/**
 * Order lifecycle state machine (task contract):
 *   NEW -> CONFIRMED -> COOKING -> READY -> COMPLETED
 *   NEW | CONFIRMED | COOKING | READY -> CANCELLED
 * COMPLETED and CANCELLED are terminal.
 */
const TRANSITIONS: Readonly<Record<OrderStatus, readonly OrderStatus[]>> = {
  NEW: [OrderStatus.CONFIRMED, OrderStatus.CANCELLED],
  CONFIRMED: [OrderStatus.COOKING, OrderStatus.CANCELLED],
  COOKING: [OrderStatus.READY, OrderStatus.CANCELLED],
  READY: [OrderStatus.COMPLETED, OrderStatus.CANCELLED],
  COMPLETED: [],
  CANCELLED: [],
};

export function canTransition(from: OrderStatus, to: OrderStatus): boolean {
  return TRANSITIONS[from].includes(to);
}

export function assertTransition(from: OrderStatus, to: OrderStatus): void {
  if (!canTransition(from, to)) {
    throw new InvalidOrderStatusTransitionError(from, to);
  }
}

export class InvalidOrderStatusTransitionError extends Error {
  override readonly name = 'InvalidOrderStatusTransitionError';

  constructor(
    readonly from: OrderStatus,
    readonly to: OrderStatus,
  ) {
    super(`Invalid order status transition: ${from} -> ${to}`);
  }
}
