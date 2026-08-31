import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';

/// An order accepted by the backend (`POST /orders` → 201 Created).
final class GuestOrder extends Equatable {
  const GuestOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
  });

  factory GuestOrder.fromJson(Map<String, dynamic> json) {
    try {
      final orderNumber = json['orderNumber'];
      if (orderNumber == null) {
        throw const FormatException('Missing orderNumber in order payload');
      }
      return GuestOrder(
        id: json['id'] as String,
        orderNumber: '$orderNumber',
        status: json['status'] as String? ?? 'NEW',
        totalAmount: Money.fromRubles((json['totalAmount'] as num?) ?? 0),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed order payload: $e');
    }
  }

  final String id;

  /// Human-facing number shown to the guest (`#1042`).
  final String orderNumber;

  /// Backend order status (`NEW`, `CONFIRMED`, …).
  final String status;

  /// Grand total computed by the backend; arrives in rubles.
  final Money totalAmount;

  @override
  List<Object?> get props => [id, orderNumber, status, totalAmount];
}
