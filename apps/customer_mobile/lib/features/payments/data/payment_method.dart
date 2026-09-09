/// Способ оплаты в контракте `POST /orders`.
enum PaymentMethod { online, onDelivery }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.online => 'Онлайн-оплата (СБП, Карты)',
    PaymentMethod.onDelivery => 'При получении (Картой курьеру / Наличными)',
  };

  String get wireName => switch (this) {
    PaymentMethod.online => 'ONLINE',
    PaymentMethod.onDelivery => 'ON_DELIVERY',
  };
}
