import { OrderStatus } from '@prisma/client';

/**
 * Order lifecycle state machine:
 *   PENDING_PAYMENT -> CONFIRMED | CANCELLED
 *   NEW -> CONFIRMED -> COOKING -> READY -> ON_WAY -> COMPLETED
 *   READY -> COMPLETED (for takeaway / dine-in)
 *   NEW | CONFIRMED | COOKING | READY | ON_WAY -> CANCELLED
 * COMPLETED and CANCELLED are terminal.
 */
const TRANSITIONS: Readonly<Record<OrderStatus, readonly OrderStatus[]>> = {
  PENDING_PAYMENT: [OrderStatus.CONFIRMED, OrderStatus.CANCELLED],
  NEW: [OrderStatus.CONFIRMED, OrderStatus.COOKING, OrderStatus.CANCELLED],
  CONFIRMED: [OrderStatus.COOKING, OrderStatus.CANCELLED],
  COOKING: [OrderStatus.READY, OrderStatus.CANCELLED],
  READY: [OrderStatus.ON_WAY, OrderStatus.COMPLETED, OrderStatus.CANCELLED],
  ON_WAY: [OrderStatus.COMPLETED, OrderStatus.CANCELLED],
  COMPLETED: [],
  CANCELLED: [],
};

export function canTransition(from: OrderStatus, to: OrderStatus): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
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
