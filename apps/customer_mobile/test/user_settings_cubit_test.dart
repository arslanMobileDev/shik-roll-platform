import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:customer_mobile/features/profile/domain/delivery_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_settings_repository.dart';

void main() {
  late FakeUserSettingsRepository repository;

  setUp(() => repository = FakeUserSettingsRepository());

  group('UserSettingsCubit', () {
    blocTest<UserSettingsCubit, UserSettingsState>(
      'начальное состояние: дефолтный скутер, настройки ещё не загружены',
      build: () => UserSettingsCubit(repository),
      expect: () => <UserSettingsState>[],
      verify: (cubit) {
        expect(cubit.state.selectedCourierVehicle, DeliveryVehicle.yellowScooter);
        expect(cubit.state.isLoaded, isFalse);
        expect(cubit.state.errorCode, isNull);
      },
    );

    blocTest<UserSettingsCubit, UserSettingsState>(
      'load без сохранённого значения выставляет дефолт и isLoaded',
      build: () => UserSettingsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<UserSettingsState>(
          (s) =>
              s.isLoaded &&
              s.selectedCourierVehicle == DeliveryVehicle.yellowScooter &&
              s.errorCode == null,
        ),
      ],
    );

    blocTest<UserSettingsCubit, UserSettingsState>(
      'load подтягивает сохранённое значение',
      build: () {
        repository = FakeUserSettingsRepository(stored: DeliveryVehicle.skateboard);
        return UserSettingsCubit(repository);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<UserSettingsState>(
          (s) => s.isLoaded && s.selectedCourierVehicle == DeliveryVehicle.skateboard,
        ),
      ],
    );

    blocTest<UserSettingsCubit, UserSettingsState>(
      'ошибка чтения не роняет load: дефолт и isLoaded',
      build: () {
        repository.readError = StateError('channel gone');
        return UserSettingsCubit(repository);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        predicate<UserSettingsState>(
          (s) =>
              s.isLoaded &&
              s.selectedCourierVehicle == DeliveryVehicle.yellowScooter &&
              s.errorCode == null,
        ),
      ],
    );

    blocTest<UserSettingsCubit, UserSettingsState>(
      'selectCourierVehicle: state обновляется до завершения записи (optimistic)',
      build: () {
        repository.writeLatency = const Duration(milliseconds: 50);
        return UserSettingsCubit(repository);
      },
      seed: () => const UserSettingsState(isLoaded: true),
      act: (cubit) => cubit.selectCourierVehicle(DeliveryVehicle.rocket),
      expect: () => [
        // Единственная эмиссия — новое значение выставлено сразу, не дожидаясь
        // окончания записи; повторной эмиссии после успешной записи нет.
        predicate<UserSettingsState>(
          (s) => s.selectedCourierVehicle == DeliveryVehicle.rocket && s.errorCode == null,
        ),
      ],
      verify: (_) {
        expect(repository.stored, DeliveryVehicle.rocket);
        expect(repository.writeCount, 1);
      },
    );

    blocTest<UserSettingsCubit, UserSettingsState>(
      'ошибка записи: откат на прежнее значение и SETTINGS_WRITE_FAILED',
      build: () {
        repository.writeError = StateError('disk full');
        return UserSettingsCubit(repository);
      },
      seed: () => const UserSettingsState(isLoaded: true),
      act: (cubit) => cubit.selectCourierVehicle(DeliveryVehicle.rocket),
      expect: () => [
        predicate<UserSettingsState>(
          (s) => s.selectedCourierVehicle == DeliveryVehicle.rocket && s.errorCode == null,
        ),
        predicate<UserSettingsState>(
          (s) =>
              s.selectedCourierVehicle == DeliveryVehicle.yellowScooter &&
              s.errorCode == UserSettingsCubit.writeFailedErrorCode,
        ),
      ],
      verify: (_) {
        // Хранилище не переключилось на неудачное значение.
        expect(repository.stored, DeliveryVehicle.yellowScooter);
      },
    );

    blocTest<UserSettingsCubit, UserSettingsState>(
      'повторный выбор того же транспорта не эмитит и не пишет',
      build: () => UserSettingsCubit(repository),
      seed: () => const UserSettingsState(isLoaded: true),
      act: (cubit) => cubit.selectCourierVehicle(DeliveryVehicle.yellowScooter),
      expect: () => <UserSettingsState>[],
      verify: (_) => expect(repository.writeCount, 0),
    );

    blocTest<UserSettingsCubit, UserSettingsState>(
      'успешный повторный выбор после ошибки очищает errorCode',
      build: () => UserSettingsCubit(repository),
      seed: () => const UserSettingsState(
        isLoaded: true,
        selectedCourierVehicle: DeliveryVehicle.yellowScooter,
        errorCode: UserSettingsCubit.writeFailedErrorCode,
      ),
      act: (cubit) => cubit.selectCourierVehicle(DeliveryVehicle.redCar),
      expect: () => [
        predicate<UserSettingsState>(
          (s) => s.selectedCourierVehicle == DeliveryVehicle.redCar && s.errorCode == null,
        ),
      ],
    );
  });
}
