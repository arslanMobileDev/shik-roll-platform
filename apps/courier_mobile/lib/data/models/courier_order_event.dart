import 'package:equatable/equatable.dart';

/// Live order event from the courier SSE stream (backend CourierOrderEvent).
/// Used to apply incremental updates and to deduplicate replays by
/// (orderId, status, timestamp) — security filtering stays server-side.
class CourierOrderEvent extends Equatable {
  const CourierOrderEvent({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.branchId,
    required this.timestamp,
    this.courierId,
    this.deliveryAddress,
    this.totalRubles,
  });

  final String orderId;
  final String orderNumber;

  /// Canonical backend status string (COOKING/READY/ON_WAY/COMPLETED/...).
  final String status;
  final String branchId;
  final String? courierId;
  final String? deliveryAddress;
  final int? totalRubles;
  final String timestamp;

  /// Deduplication key for repeated deliveries of the same change.
  String get dedupKey => '$orderId:$status:$timestamp';

  factory CourierOrderEvent.fromJson(Map<String, dynamic> json) =>
      CourierOrderEvent(
        orderId: json['orderId'] as String? ?? '',
        orderNumber: json['orderNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        branchId: json['branchId'] as String? ?? '',
        courierId: json['courierId'] as String?,
        deliveryAddress: json['deliveryAddress'] as String?,
        totalRubles: (json['totalRubles'] as num?)?.toInt(),
        timestamp: json['timestamp'] as String? ?? '',
      );

  @override
  List<Object?> get props => [
    orderId,
    orderNumber,
    status,
    branchId,
    courierId,
    deliveryAddress,
    totalRubles,
    timestamp,
  ];
}
