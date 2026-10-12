import 'package:customer_mobile/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// ICU `ru_RU` separates both the digit groups and the currency symbol with a
/// non-breaking space (U+00A0), so expectations are written as readable prices
/// and swapped here.
String _rub(String readable) => readable.replaceAll(' ', ' ');

void main() {
  group('Money.formatCompact', () {
    test('drops the kopeck tail when it is zero', () {
      expect(const Money.kopecks(149000).formatCompact(), _rub('1 490 ₽'));
      expect(const Money.kopecks(16000).formatCompact(), _rub('160 ₽'));
      expect(Money.zero.formatCompact(), _rub('0 ₽'));
    });

    test('keeps kopecks when the price has them', () {
      expect(const Money.kopecks(149050).formatCompact(), _rub('1 490,50 ₽'));
      expect(const Money.kopecks(999).formatCompact(), _rub('9,99 ₽'));
    });

    test('format() still renders the full kopeck form for cart and receipt', () {
      expect(const Money.kopecks(149000).format(), _rub('1 490,00 ₽'));
    });
  });
}
