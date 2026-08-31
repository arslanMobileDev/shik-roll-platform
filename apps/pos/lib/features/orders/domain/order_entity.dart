import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';

/// How the order is served; mirrors the Orders API `orderType` values.
enum OrderType {
  takeaway('TAKEAWAY'),
  dineIn('DINE_IN');

  const OrderType(this.wireName);

  /// Value expected by `POST /orders`.
  final String wireName;
}

/// An order accepted by the backend (`POST /orders` → 201 Created).
final class OrderEntity extends Equatable {
  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
  });

  factory OrderEntity.fromJson(Map<String, dynamic> json) {
    try {
      return OrderEntity(
        id: json['id'] as String,
        orderNumber: '${json['orderNumber']}',
        status: json['status'] as String? ?? 'NEW',
        totalAmount: Money.fromRubles((json['totalAmount'] as num?) ?? 0),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed order payload: $e');
    }
  }

  final String id;

  /// Human-facing number shown to the cashier and the kitchen (`#1005`).
  final String orderNumber;

  /// Backend order status (`NEW`, `CONFIRMED`, …).
  final String status;

  /// Grand total computed by the backend; arrives in rubles.
  final Money totalAmount;

  @override
  List<Object?> get props => [id, orderNumber, status, totalAmount];
}
