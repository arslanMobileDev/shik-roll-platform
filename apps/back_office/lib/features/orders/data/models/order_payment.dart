import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

/// Payment provider (openapi PaymentEntity.provider).
enum PaymentProvider {
  yookassa('YOOKASSA', 'ЮKassa'),
  cash('CASH', 'Наличные'),
  terminal('TERMINAL', 'Терминал');

  const PaymentProvider(this.wireName, this.label);

  final String wireName;
  final String label;

  static PaymentProvider fromJson(String value) =>
      PaymentProvider.values.firstWhere(
        (p) => p.wireName == value,
        orElse: () => PaymentProvider.cash,
      );
}

/// Payment lifecycle status (openapi PaymentEntity.status).
enum PaymentStatus {
  pending('PENDING', 'Ожидает оплаты'),
  succeeded('SUCCEEDED', 'Оплачен'),
  canceled('CANCELED', 'Отменён');

  const PaymentStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static PaymentStatus fromJson(String value) =>
      PaymentStatus.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => PaymentStatus.pending,
      );
}

/// Payment record of an order (openapi PaymentEntity) — the fiscalization
/// (54-ФЗ) evidence surfaced in the order details.
final class OrderPayment extends Equatable {
  const OrderPayment({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.status,
    required this.amount,
    required this.currency,
    required this.idempotenceKey,
    required this.createdAt,
    this.paymentUrl,
    this.externalPaymentId,
  });

  final String id;
  final String orderId;
  final PaymentProvider provider;
  final PaymentStatus status;
  final Money amount;
  final String currency;

  /// Idempotency key the payment was created with (54-ФЗ safe retries).
  final String idempotenceKey;
  final DateTime createdAt;
  final String? paymentUrl;

  /// Provider-side payment id (e.g. YooKassa object.id).
  final String? externalPaymentId;

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
    id: json['id'] as String? ?? '',
    orderId: json['orderId'] as String? ?? '',
    provider: PaymentProvider.fromJson(json['provider'] as String? ?? ''),
    status: PaymentStatus.fromJson(json['status'] as String? ?? ''),
    amount: switch (json['amount']) {
      final num rubles => Money.fromRubles(rubles.toDouble()),
      _ => Money.zero,
    },
    currency: json['currency'] as String? ?? 'RUB',
    idempotenceKey: json['idempotenceKey'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    paymentUrl: json['paymentUrl'] as String?,
    externalPaymentId: json['externalPaymentId'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    orderId,
    provider,
    status,
    amount,
    currency,
    idempotenceKey,
    createdAt,
    paymentUrl,
    externalPaymentId,
  ];
}
