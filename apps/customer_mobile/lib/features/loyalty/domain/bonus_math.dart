import 'dart:math';

import '../../../core/utils/money.dart';

/// Bonus calculation rules (ADR-1614), client-side mirror of the backend
/// `bonus-rules.ts` for preview purposes only:
/// - 1 bonus point = 1 RUB, points are integers (fractional values forbidden);
/// - a spend never exceeds 30% of the item amount after promotion discounts
///   and before bonuses (the "bonus base");
/// - cashback is earned on the actually paid item amount after all discounts.
///
/// The server re-checks every rule at checkout — client values are hints.

/// Maximum share of the bonus base payable with points, in percent.
const int maxBonusSharePercent = 30;

/// Hard 30% limit: how many points the bonus base allows at most.
///
/// Integer math on kopecks: `floor(base * 0.30)` in whole rubles.
int bonusLimitPoints(Money bonusBase) {
  if (bonusBase.minorUnits <= 0) return 0;
  return (bonusBase.minorUnits * maxBonusSharePercent) ~/ 10000;
}

/// Points actually applicable at checkout: the 30% limit capped by the
/// account balance (`max_bonus_points = min(balance, floor(base * 0.30))`).
int maxBonusPoints(Money bonusBase, int balance) {
  return min(max(balance, 0), bonusLimitPoints(bonusBase));
}

/// Cashback preview: `floor(payable * rate / 100)`. The rate is a percentage
/// (0..100); a zero rate or non-positive amount earns nothing.
int cashbackPointsFor(Money payableAmount, double cashbackRatePercent) {
  if (payableAmount.minorUnits <= 0 || cashbackRatePercent <= 0) return 0;
  return (payableAmount.rubles * cashbackRatePercent / 100).floor();
}
