import 'package:customer_mobile/features/profile/data/user_settings_repository.dart';
import 'package:customer_mobile/features/profile/domain/delivery_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

const _key = SharedPreferencesUserSettingsRepository.selectedCourierVehicleKey;

void main() {
  late _MockSharedPreferences prefs;
  late SharedPreferencesUserSettingsRepository repository;

  setUp(() {
    prefs = _MockSharedPreferences();
    repository = SharedPreferencesUserSettingsRepository(prefs);
  });

  group('SharedPreferencesUserSettingsRepository', () {
    test('отсутствующее значение читается как дефолтный жёлтый скутер', () async {
      when(() => prefs.getString(_key)).thenReturn(null);

      expect(await repository.readCourierVehicle(), DeliveryVehicle.yellowScooter);
      verifyNever(() => prefs.setString(any(), any()));
    });

    test('валидное сохранённое значение возвращается как есть', () async {
      when(() => prefs.getString(_key)).thenReturn('skateboard');

      expect(await repository.readCourierVehicle(), DeliveryVehicle.skateboard);
    });

    test('неизвестное значение: дефолт без exception, storage перезаписан', () async {
      when(() => prefs.getString(_key)).thenReturn('hoverboard');
      when(() => prefs.setString(_key, 'yellowScooter'))
          .thenAnswer((_) async => true);

      expect(await repository.readCourierVehicle(), DeliveryVehicle.yellowScooter);
      verify(() => prefs.setString(_key, 'yellowScooter')).called(1);
    });

    test('запись сохраняет стабильное enum name', () async {
      when(() => prefs.setString(_key, 'rocket')).thenAnswer((_) async => true);

      await repository.writeCourierVehicle(DeliveryVehicle.rocket);

      verify(() => prefs.setString(_key, 'rocket')).called(1);
    });

    test('setString вернул false — UserSettingsWriteException', () async {
      when(() => prefs.setString(_key, 'redCar')).thenAnswer((_) async => false);

      await expectLater(
        repository.writeCourierVehicle(DeliveryVehicle.redCar),
        throwsA(isA<UserSettingsWriteException>()),
      );
    });

    test('платформенная ошибка записи пробрасывается наверх', () async {
      when(() => prefs.setString(_key, 'redCar'))
          .thenThrow(StateError('channel gone'));

      await expectLater(
        repository.writeCourierVehicle(DeliveryVehicle.redCar),
        throwsA(isA<StateError>()),
      );
    });
  });
}
