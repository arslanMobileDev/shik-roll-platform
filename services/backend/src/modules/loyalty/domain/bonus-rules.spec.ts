import { Prisma } from '@prisma/client';
import {
  bonusLimitPoints,
  cashbackPoints,
  maxBonusPoints,
} from './bonus-rules';

const D = (value: string | number) => new Prisma.Decimal(value);

describe('bonus-rules (ADR-1614)', () => {
  describe('bonusLimitPoints — the 30% limit', () => {
    it('allows exactly 30% of a round base', () => {
      expect(bonusLimitPoints(D('900.00'))).toBe(270);
    });

    it('floors fractional points (fractional bonuses are forbidden)', () => {
      // 999 * 0.30 = 299.7 -> 299
      expect(bonusLimitPoints(D('999.00'))).toBe(299);
    });

    it('rounds down sub-point bases to zero', () => {
      // 3 * 0.30 = 0.9 -> 0
      expect(bonusLimitPoints(D('3.00'))).toBe(0);
      expect(bonusLimitPoints(D('1.00'))).toBe(0);
    });

    it('returns zero for a zero or negative base', () => {
      expect(bonusLimitPoints(D('0.00'))).toBe(0);
      expect(bonusLimitPoints(D('-100.00'))).toBe(0);
    });

    it('handles kopecks precisely (Decimal, no float error)', () => {
      // 333.33 * 0.30 = 99.999 -> 99
      expect(bonusLimitPoints(D('333.33'))).toBe(99);
    });
  });

  describe('maxBonusPoints — limit capped by the balance', () => {
    it('is the 30% limit when the balance covers it', () => {
      expect(maxBonusPoints(D('900.00'), 1000)).toBe(270);
    });

    it('is the balance when it is below the limit', () => {
      expect(maxBonusPoints(D('900.00'), 100)).toBe(100);
    });

    it('is zero for an empty balance', () => {
      expect(maxBonusPoints(D('900.00'), 0)).toBe(0);
    });

    it('never goes negative', () => {
      expect(maxBonusPoints(D('900.00'), -50)).toBe(0);
      expect(maxBonusPoints(D('0.00'), 100)).toBe(0);
    });
  });

  describe('cashbackPoints — floor(payable * rate / 100)', () => {
    it('earns the exact percentage on round amounts', () => {
      // 800 * 5% = 40
      expect(cashbackPoints(D('800.00'), D('5.00'))).toBe(40);
    });

    it('floors fractional points', () => {
      // 999 * 5% = 49.95 -> 49
      expect(cashbackPoints(D('999.00'), D('5.00'))).toBe(49);
    });

    it('supports fractional rates', () => {
      // 1000 * 7.5% = 75
      expect(cashbackPoints(D('1000.00'), D('7.50'))).toBe(75);
      // 555 * 7.5% = 41.625 -> 41
      expect(cashbackPoints(D('555.00'), D('7.50'))).toBe(41);
    });

    it('earns nothing at a zero rate (ledger rows are never zero)', () => {
      expect(cashbackPoints(D('800.00'), D('0.00'))).toBe(0);
    });

    it('earns nothing on a zero or negative payable amount', () => {
      expect(cashbackPoints(D('0.00'), D('5.00'))).toBe(0);
      expect(cashbackPoints(D('-10.00'), D('5.00'))).toBe(0);
    });

    it('supports a 100% rate boundary', () => {
      expect(cashbackPoints(D('123.45'), D('100.00'))).toBe(123);
    });
  });
});
