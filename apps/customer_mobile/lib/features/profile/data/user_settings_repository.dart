import 'package:shared_preferences/shared_preferences.dart';

import '../domain/delivery_vehicle.dart';

/// Локальные UI-настройки гостя (ADR-1616). Секреты и персональные данные
/// здесь не хранятся; ключ не привязан к customer id и переживает logout.
abstract interface class UserSettingsRepository {
  Future<DeliveryVehicle> readCourierVehicle();
  Future<void> writeCourierVehicle(DeliveryVehicle vehicle);
}

/// Ошибка записи настройки в локальное хранилище.
final class UserSettingsWriteException implements Exception {
  const UserSettingsWriteException();

  @override
  String toString() => 'UserSettingsWriteException: failed to persist setting';
}

/// Хранение настроек в SharedPreferences. Неизвестное или повреждённое
/// значение не приводит к exception: возвращается дефолт, а storage
/// перезаписывается корректным значением.
final class SharedPreferencesUserSettingsRepository
    implements UserSettingsRepository {
  SharedPreferencesUserSettingsRepository(this._prefs);

  static const selectedCourierVehicleKey = 'selected_courier_vehicle';

  static const defaultVehicle = DeliveryVehicle.yellowScooter;

  final SharedPreferences _prefs;

  @override
  Future<DeliveryVehicle> readCourierVehicle() async {
    final raw = _prefs.getString(selectedCourierVehicleKey);
    if (raw == null) return defaultVehicle;
    for (final vehicle in DeliveryVehicle.values) {
      if (vehicle.name == raw) return vehicle;
    }
    // Самовосстановление: повреждённое значение заменяем дефолтом.
    await writeCourierVehicle(defaultVehicle);
    return defaultVehicle;
  }

  @override
  Future<void> writeCourierVehicle(DeliveryVehicle vehicle) async {
    final saved = await _prefs.setString(
      selectedCourierVehicleKey,
      vehicle.name,
    );
    if (!saved) {
      throw const UserSettingsWriteException();
    }
  }
}
