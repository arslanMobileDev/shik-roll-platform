import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Exact decimal money value for RUB-denominated catalog and cart math.
///
/// Amounts are stored as integer minor units (kopecks), which gives exact
/// decimal semantics for a 2-digit currency: no binary floating-point
/// drift when summing cart lines or applying modifier surcharges.
final class Money extends Equatable implements Comparable<Money> {
  const Money.kopecks(this.minorUnits);

  /// Parses an API price value (rubles, e.g. 390.0) into kopecks.
  factory Money.fromRubles(num rubles) =>
      Money.kopecks((rubles * 100).round());

  static const Money zero = Money.kopecks(0);

  /// Amount in minor units (kopecks for RUB).
  final int minorUnits;

  double get rubles => minorUnits / 100;

  Money operator +(Money other) =>
      Money.kopecks(minorUnits + other.minorUnits);

  Money operator -(Money other) =>
      Money.kopecks(minorUnits - other.minorUnits);

  Money operator *(int quantity) => Money.kopecks(minorUnits * quantity);

  bool get isZero => minorUnits == 0;

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  /// Formats as localized RUB currency, e.g. `1 234,00 ₽`.
  String format({String locale = 'ru_RU', String symbol = '₽'}) {
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    ).format(rubles);
  }

  @override
  String toString() => 'Money($minorUnits)';

  @override
  List<Object?> get props => [minorUnits];
}
