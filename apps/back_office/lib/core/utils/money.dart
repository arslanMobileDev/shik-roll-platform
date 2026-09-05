import 'package:intl/intl.dart';

/// Money value object backed by integer minor units (kopecks for RUB).
final class Money {
  const Money(this.minorUnits);

  /// Zero value.
  static const Money zero = Money(0);

  /// Amount in minor units (e.g. kopecks). 34990 = 349.90 RUB.
  final int minorUnits;

  factory Money.fromRubles(double rubles) =>
      Money((rubles * 100).round());

  /// Parses user input like `349`, `349.9`, `349,90` or `1 234,56`.
  ///
  /// Throws [FormatException] on empty or non-numeric input.
  factory Money.parse(String raw) {
    final normalized = raw
        .replaceAll('\u00A0', '') // NBSP (ru_RU grouping)
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    if (normalized.isEmpty) {
      throw const FormatException('Empty amount');
    }
    final value = double.tryParse(normalized);
    if (value == null || value.isNaN || value.isInfinite) {
      throw FormatException('Invalid amount: $raw');
    }
    return Money.fromRubles(value);
  }

  double get rubles => minorUnits / 100;

  /// RUB wire value for JSON payloads (major units, 2 decimals).
  double toJson() => rubles;

  /// Formats as `1 234,56 ₽` using ru_RU grouping.
  String format() {
    final formatter = NumberFormat('#,##0.00', 'ru_RU');
    return '${formatter.format(rubles)} ₽';
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'Money($minorUnits)';
}
