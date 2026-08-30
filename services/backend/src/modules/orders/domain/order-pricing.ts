import { Prisma } from '@prisma/client';

export interface PricedModifier {
  priceDelta: Prisma.Decimal;
  quantity: number;
}

export interface PricedItem {
  unitPrice: Prisma.Decimal;
  quantity: number;
  modifiers: PricedModifier[];
}

const HUNDRED = new Prisma.Decimal(100);

function round2(value: Prisma.Decimal): Prisma.Decimal {
  return value.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
}

/**
 * Server-side line total (BE-907: price is always recalculated on the server):
 * (unit price + sum of modifier deltas) x quantity, Decimal(10,2) RUB.
 */
export function lineTotal(item: PricedItem): Prisma.Decimal {
  const modifierDelta = item.modifiers.reduce(
    (sum, modifier) =>
      sum.plus(modifier.priceDelta.times(modifier.quantity)),
    new Prisma.Decimal(0),
  );
  const quantity = new Prisma.Decimal(item.quantity);
  return round2(item.unitPrice.plus(modifierDelta).times(quantity));
}

/** Order subtotal: sum of line totals. */
export function orderSubtotal(items: PricedItem[]): Prisma.Decimal {
  return round2(
    items.reduce(
      (sum, item) => sum.plus(lineTotal(item)),
      new Prisma.Decimal(0),
    ),
  );
}

/**
 * Order total. Delivery fee / discounts / tips land in later iterations
 * (DB-608 order_discounts / order_tips), so for now total == subtotal.
 */
export function orderTotal(subtotal: Prisma.Decimal): Prisma.Decimal {
  return round2(subtotal.times(HUNDRED).div(HUNDRED));
}
