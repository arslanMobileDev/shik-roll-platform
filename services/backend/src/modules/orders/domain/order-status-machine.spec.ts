import { OrderStatus } from '@prisma/client';
import {
  assertTransition,
  canTransition,
  InvalidOrderStatusTransitionError,
} from './order-status-machine';

describe('order status state machine', () => {
  const { NEW, CONFIRMED, COOKING, READY, COMPLETED, CANCELLED } = OrderStatus;

  it.each([
    [NEW, CONFIRMED],
    [NEW, CANCELLED],
    [CONFIRMED, COOKING],
    [CONFIRMED, CANCELLED],
    [COOKING, READY],
    [COOKING, CANCELLED],
    [READY, COMPLETED],
    [READY, CANCELLED],
  ])('allows %s -> %s', (from, to) => {
    expect(canTransition(from, to)).toBe(true);
    expect(() => assertTransition(from, to)).not.toThrow();
  });

  it.each([
    [NEW, COOKING],
    [NEW, READY],
    [NEW, COMPLETED],
    [NEW, NEW],
    [CONFIRMED, NEW],
    [CONFIRMED, READY],
    [CONFIRMED, COMPLETED],
    [COOKING, NEW],
    [COOKING, CONFIRMED],
    [COOKING, COMPLETED],
    [READY, NEW],
    [READY, COOKING],
    [COMPLETED, NEW],
    [COMPLETED, CONFIRMED],
    [COMPLETED, COOKING],
    [COMPLETED, READY],
    [COMPLETED, CANCELLED],
    [CANCELLED, NEW],
    [CANCELLED, CONFIRMED],
    [CANCELLED, COOKING],
    [CANCELLED, READY],
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
