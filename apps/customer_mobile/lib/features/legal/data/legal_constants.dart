/// Реквизиты оператора и платёжно-фискальный контур (152-ФЗ / 54-ФЗ).
///
/// Единый источник правды для всех правовых поверхностей гостевого
/// приложения: публичная оферта, политика конфиденциальности, сноски
/// на экране чекаута.
abstract final class LegalConstants {
  /// Продавец и оператор персональных данных.
  static const operatorName = 'ИП Хаджимуратов Муслим Мусаевич';
  static const operatorInn = '263005668270';
  static const operatorOgrnip = '325265100073290';

  /// Концепция ресторана.
  static const concept = '100% Halal';

  /// Провайдер онлайн-оплаты.
  static const paymentProvider = 'ЮKassa (ООО НКО «ЮМани», банк ВТБ)';

  /// Фискализация чеков.
  static const fiscalization = '54-ФЗ (онлайн-касса Атол Сигма)';

  /// Локализация серверов и баз данных персональных данных (152-ФЗ РФ).
  static const hostingProvider =
      'ООО «Таймвэб.Облако» (Timeweb Cloud, г. Санкт-Петербург)';

  /// Контактный e-mail поддержки.
  static const supportEmail = 'support@shik-roll.ru';
}
