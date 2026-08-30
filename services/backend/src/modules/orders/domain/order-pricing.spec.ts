import { Prisma } from '@prisma/client';
import { lineTotal, orderSubtotal, orderTotal } from './order-pricing';

const D = (value: string | number) => new Prisma.Decimal(value);

describe('order pricing (Decimal, RUB)', () => {
  it('computes a line total without modifiers', () => {
    const total = lineTotal({ unitPrice: D('400.00'), quantity: 2, modifiers: [] });
    expect(total.toString()).toBe('800');
  });

  it('adds modifier deltas before multiplying by quantity', () => {
    const total = lineTotal({
      unitPrice: D('400.00'),
      quantity: 2,
      modifiers: [
        { priceDelta: D('50.00'), quantity: 1 },
        { priceDelta: D('25.50'), quantity: 2 },
      ],
    });
    // (400 + 50 + 51) * 2 = 1002
    expect(total.toString()).toBe('1002');
  });

  it('rounds to 2 decimal places', () => {
    const total = lineTotal({
      unitPrice: D('199.995'),
      quantity: 1,
      modifiers: [],
    });
    expect(total.toString()).toBe('200');
  });

  it('sums line totals into the subtotal', () => {
    const subtotal = orderSubtotal([
      { unitPrice: D('400.00'), quantity: 1, modifiers: [] },
      { unitPrice: D('250.00'), quantity: 2, modifiers: [{ priceDelta: D('10'), quantity: 1 }] },
    ]);
    // 400 + (260 * 2) = 920
    expect(subtotal.toString()).toBe('920');
  });

  it('keeps total equal to subtotal until discounts/fees land', () => {
    expect(orderTotal(D('920.00')).toString()).toBe('920');
  });

  it('handles zero-quantity modifiers gracefully', () => {
    const total = lineTotal({
      unitPrice: D('100'),
      quantity: 1,
      modifiers: [{ priceDelta: D('30'), quantity: 0 }],
    });
    expect(total.toString()).toBe('100');
  });
});
