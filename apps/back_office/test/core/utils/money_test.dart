import 'package:back_office/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.parse', () {
    test('parses plain rubles', () {
      expect(Money.parse('349'), const Money(34900));
    });

    test('parses dot decimals', () {
      expect(Money.parse('349.90'), const Money(34990));
    });

    test('parses comma decimals', () {
      expect(Money.parse('349,90'), const Money(34990));
    });

    test('parses grouped input with spaces and NBSP', () {
      expect(Money.parse('1 234,56'), const Money(123456));
      expect(Money.parse('1\u00A0234,56'), const Money(123456));
    });

    test('rounds to kopecks', () {
      expect(Money.parse('10.999'), const Money(1100));
    });

    test('throws on empty input', () {
      expect(() => Money.parse('   '), throwsFormatException);
    });

    test('throws on non-numeric input', () {
      expect(() => Money.parse('12.3.4'), throwsFormatException);
      expect(() => Money.parse('abc'), throwsFormatException);
    });
  });

  group('Money.format', () {
    test('formats with ru_RU grouping and ruble sign', () {
      final formatted = const Money(123456).format().replaceAll('\u00A0', ' ');
      expect(formatted, '1 234,56 ₽');
    });

    test('formats zero', () {
      final formatted = Money.zero.format().replaceAll('\u00A0', ' ');
      expect(formatted, '0,00 ₽');
    });
  });

  group('Money wire value', () {
    test('toJson returns major units', () {
      expect(const Money(34990).toJson(), 349.90);
    });

    test('equality by minor units', () {
      expect(const Money(100), Money.fromRubles(1.0));
      expect(const Money(100), isNot(const Money(101)));
    });
  });
}
