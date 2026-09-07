import 'package:customer_mobile/features/profile/data/user_settings_repository.dart';
import 'package:customer_mobile/features/profile/domain/delivery_vehicle.dart';

/// In-memory реализация [UserSettingsRepository] для тестов: без platform
/// channel, с управляемыми задержкой и ошибками чтения/записи.
final class FakeUserSettingsRepository implements UserSettingsRepository {
  FakeUserSettingsRepository({DeliveryVehicle? stored})
    : stored = stored ?? DeliveryVehicle.yellowScooter;

  DeliveryVehicle stored;
  Object? readError;
  Object? writeError;
  Duration writeLatency = Duration.zero;
  int writeCount = 0;

  @override
  Future<DeliveryVehicle> readCourierVehicle() async {
    if (readError != null) throw readError!;
    return stored;
  }

  @override
  Future<void> writeCourierVehicle(DeliveryVehicle vehicle) async {
    writeCount++;
    if (writeLatency > Duration.zero) {
      await Future<void>.delayed(writeLatency);
    }
    if (writeError != null) throw writeError!;
    stored = vehicle;
  }
}
