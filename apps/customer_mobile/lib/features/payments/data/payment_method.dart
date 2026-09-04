/// Способ оплаты на чекауте гостя (DB-602 / API-702).
enum PaymentMethod { yookassa, cash, terminal }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.yookassa => 'Онлайн (СБП, Картой через ЮKassa)',
    PaymentMethod.cash => 'Наличными при получении',
    PaymentMethod.terminal => 'Картой курьеру / на стойке',
  };
}
