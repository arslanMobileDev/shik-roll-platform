/// Транспорт курьера, выбранный гостем как «скин» доставки (ADR-1616).
///
/// Единый enum для профиля и трекера заказа; в storage сохраняется только
/// стабильное [DeliveryVehicle.name].
enum DeliveryVehicle {
  yellowScooter,
  redCar,
  rocket,
  skateboard,
}

/// Presentation-метаданные транспорта: подпись, ассет и эмодзи-фолбэк.
/// В персистентность не попадают — storage хранит только enum name.
extension DeliveryVehiclePresentation on DeliveryVehicle {
  String get label => switch (this) {
    DeliveryVehicle.yellowScooter => 'Жёлтый скутер',
    DeliveryVehicle.redCar => 'Красный авто',
    DeliveryVehicle.rocket => 'Ракета-доставка',
    DeliveryVehicle.skateboard => 'Скейтборд',
  };

  String get imageUrl => switch (this) {
    DeliveryVehicle.yellowScooter => 'assets/icons/delivery_scooter.webp',
    DeliveryVehicle.redCar => 'assets/icons/delivery_car.webp',
    DeliveryVehicle.rocket => 'assets/icons/delivery_rocket.webp',
    DeliveryVehicle.skateboard => 'assets/icons/delivery_skateboard.webp',
  };

  String get fallbackEmoji => switch (this) {
    DeliveryVehicle.yellowScooter => '🛵',
    DeliveryVehicle.redCar => '🚗',
    DeliveryVehicle.rocket => '🚀',
    DeliveryVehicle.skateboard => '🛹',
  };
}
