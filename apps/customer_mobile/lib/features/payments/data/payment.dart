import 'package:equatable/equatable.dart';

/// Статус платежа в эквайринге (API-702: `PENDING` | `SUCCEEDED`).
enum PaymentStatus { pending, succeeded }

/// Платёж, созданный через `POST /payments/create` (API-702 / DB-602).
final class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.paymentUrl,
    required this.status,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    try {
      final paymentId = json['paymentId'];
      final paymentUrl = json['paymentUrl'];
      if (paymentId == null || paymentUrl == null) {
        throw const FormatException(
          'Missing paymentId/paymentUrl in payment payload',
        );
      }
      return Payment(
        id: paymentId as String,
        paymentUrl: paymentUrl as String,
        status: switch ((json['status'] as String? ?? 'PENDING')
            .toUpperCase()) {
          'SUCCEEDED' => PaymentStatus.succeeded,
          _ => PaymentStatus.pending,
        },
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed payment payload: $e');
    }
  }

  final String id;

  /// Ссылка на страницу оплаты ЮKassa (confirmation URL).
  final String paymentUrl;

  final PaymentStatus status;

  bool get isSucceeded => status == PaymentStatus.succeeded;

  @override
  List<Object?> get props => [id, paymentUrl, status];
}
