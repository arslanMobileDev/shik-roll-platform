import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/utils/money.dart';

void main() {
  group('Money', () {
    test('parses rubles into exact minor units', () {
      expect(const Money.kopecks(39000).minorUnits, 39000);
      expect(Money.fromRubles(390).minorUnits, 39000);
      expect(Money.fromRubles(390.55).minorUnits, 39055);
    });

    test('adds and multiplies without floating-point drift', () {
      final a = Money.fromRubles(0.1);
      final b = Money.fromRubles(0.2);
      // 0.1 + 0.2 in doubles is 0.30000000000000004; kopecks stay exact.
      expect(a + b, const Money.kopecks(30));
      expect(const Money.kopecks(1599) * 3, const Money.kopecks(4797));
    });

    test('subtracts and compares', () {
      expect(
        const Money.kopecks(5000) - const Money.kopecks(1200),
        const Money.kopecks(3800),
      );
      expect(
        const Money.kopecks(100).compareTo(const Money.kopecks(200)),
        isNegative,
      );
    });

    test('formats as RUB currency', () {
      final formatted = const Money.kopecks(123456).format();
      // Locale uses non-breaking group separators; normalize before compare.
      final normalized = formatted
          .replaceAll(' ', ' ')
          .replaceAll(' ', ' ');
      expect(normalized, '1 234,56 ₽');
    });

    test('zero detection', () {
      expect(Money.zero.isZero, isTrue);
      expect(const Money.kopecks(1).isZero, isFalse);
    });
  });
}
