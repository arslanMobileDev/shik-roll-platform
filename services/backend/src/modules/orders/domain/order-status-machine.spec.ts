import { OrderStatus } from '@prisma/client';
import {
  assertTransition,
  canTransition,
  InvalidOrderStatusTransitionError,
} from './order-status-machine';

describe('order status state machine', () => {
  const {
    PENDING_PAYMENT,
    NEW,
    CONFIRMED,
    COOKING,
    READY,
    ON_WAY,
    COMPLETED,
    CANCELLED,
  } = OrderStatus;

  it.each([
    [PENDING_PAYMENT, CONFIRMED],
    [PENDING_PAYMENT, CANCELLED],
    [NEW, CONFIRMED],
    [NEW, COOKING], // fast path for paid online orders (send-to-kitchen job)
    [NEW, CANCELLED],
    [CONFIRMED, COOKING],
    [CONFIRMED, CANCELLED],
    [COOKING, READY],
    [COOKING, CANCELLED],
    [READY, ON_WAY],
    [READY, COMPLETED], // takeaway / dine-in skip delivery
    [READY, CANCELLED],
    [ON_WAY, COMPLETED],
    [ON_WAY, CANCELLED],
  ])('allows %s -> %s', (from, to) => {
    expect(canTransition(from, to)).toBe(true);
    expect(() => assertTransition(from, to)).not.toThrow();
  });

  it.each([
    [PENDING_PAYMENT, PENDING_PAYMENT],
    [PENDING_PAYMENT, NEW],
    [PENDING_PAYMENT, COOKING],
    [PENDING_PAYMENT, READY],
    [PENDING_PAYMENT, ON_WAY],
    [PENDING_PAYMENT, COMPLETED],
    [NEW, READY],
    [NEW, ON_WAY],
    [NEW, COMPLETED],
    [NEW, NEW],
    [CONFIRMED, NEW],
    [CONFIRMED, READY],
    [CONFIRMED, ON_WAY],
    [CONFIRMED, COMPLETED],
    [COOKING, NEW],
    [COOKING, CONFIRMED],
    [COOKING, ON_WAY],
    [COOKING, COMPLETED],
    [READY, NEW],
    [READY, COOKING],
    [ON_WAY, NEW],
    [ON_WAY, COOKING],
    [ON_WAY, READY],
    [COMPLETED, NEW],
    [COMPLETED, CONFIRMED],
    [COMPLETED, COOKING],
    [COMPLETED, READY],
    [COMPLETED, ON_WAY],
    [COMPLETED, CANCELLED],
    [CANCELLED, NEW],
    [CANCELLED, CONFIRMED],
    [CANCELLED, COOKING],
    [CANCELLED, READY],
    [CANCELLED, ON_WAY],
    [CANCELLED, COMPLETED],
  ])('rejects %s -> %s', (from, to) => {
    expect(canTransition(from, to)).toBe(false);
    expect(() => assertTransition(from, to)).toThrow(
      InvalidOrderStatusTransitionError,
    );
  });

  it('marks COMPLETED and CANCELLED as terminal', () => {
    for (const to of Object.values(OrderStatus)) {
      expect(canTransition(COMPLETED, to)).toBe(false);
      expect(canTransition(CANCELLED, to)).toBe(false);
    }
  });

  it('carries from/to in the error', () => {
    try {
      assertTransition(NEW, COMPLETED);
      fail('expected to throw');
    } catch (error) {
      const err = error as InvalidOrderStatusTransitionError;
      expect(err.from).toBe(NEW);
      expect(err.to).toBe(COMPLETED);
      expect(err.message).toBe('Invalid order status transition: NEW -> COMPLETED');
    }
  });
});
