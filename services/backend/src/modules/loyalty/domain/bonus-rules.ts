import { Prisma } from '@prisma/client';

/**
 * Bonus calculation rules (ADR-1614):
 * - 1 bonus point = 1 RUB, points are integers (fractional values forbidden);
 * - a spend never exceeds 30% of the item amount after promotion discounts
 *   and before bonuses (the "bonus base");
 * - cashback is earned on the actually paid item amount after all discounts.
 */

/** Maximum share of the bonus base payable with points (30%). */
export const MAX_BONUS_SHARE = new Prisma.Decimal('0.30');

const HUNDRED = new Prisma.Decimal(100);

function floorToInt(value: Prisma.Decimal): number {
  return value.toDecimalPlaces(0, Prisma.Decimal.ROUND_DOWN).toNumber();
}

/** Hard 30% limit: how many points the bonus base allows at most. */
export function bonusLimitPoints(bonusBase: Prisma.Decimal): number {
  if (bonusBase.lte(0)) {
    return 0;
  }
  return floorToInt(bonusBase.times(MAX_BONUS_SHARE));
}

/**
 * Points actually applicable at checkout: the 30% limit capped by the
 * account balance (ADR-1614: max_bonus_points = min(balance, floor(base * 0.30))).
 */
export function maxBonusPoints(
  bonusBase: Prisma.Decimal,
  balance: number,
): number {
  return Math.min(Math.max(balance, 0), bonusLimitPoints(bonusBase));
}

/**
 * Cashback for a completed order: floor(payable_amount * rate / 100).
 * The rate is a percentage (Decimal(5,2), 0..100); a zero rate or a
 * non-positive payable amount earns nothing (ledger rows are never zero).
 */
export function cashbackPoints(
  payableAmount: Prisma.Decimal,
  cashbackRatePercent: Prisma.Decimal,
): number {
  if (payableAmount.lte(0) || cashbackRatePercent.lte(0)) {
    return 0;
  }
  return floorToInt(payableAmount.times(cashbackRatePercent).div(HUNDRED));
}
