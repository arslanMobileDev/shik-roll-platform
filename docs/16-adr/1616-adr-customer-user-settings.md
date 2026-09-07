---
Document ID: ADR-1616

Document Name: ADR - CUSTOMER USER SETTINGS

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: September 2026
Last Updated: September 2026

Classification: Internal
---

# ADR - CUSTOMER USER SETTINGS

## Status

Accepted

## Context

`OrderStatusTracker` хранит выбранный транспорт локально в State, поэтому настройка сбрасывается при пересоздании экрана. В Customer Mobile уже используется `flutter_bloc`, но отсутствуют `shared_preferences` и `hydrated_bloc`.

## Decision

Использовать `shared_preferences` через repository abstraction и `UserSettingsCubit`. Для одного небольшого несекретного enum-значения HydratedBloc не вводится. Секреты и персональные данные в этот storage не записываются.

Постоянный ключ: `selected_courier_vehicle`.

Стабильные значения: `yellowScooter`, `redCar`, `rocket`, `skateboard`. Дефолт при отсутствии, повреждении или неизвестном значении: `DeliveryVehicle.yellowScooter`.

## Domain And Storage Contracts

`DeliveryVehicle` переносится из widget-файла в `apps/customer_mobile/lib/features/profile/domain/delivery_vehicle.dart`, чтобы профиль и tracker зависели от одного enum.

```dart
enum DeliveryVehicle {
  yellowScooter,
  redCar,
  rocket,
  skateboard,
}

abstract interface class UserSettingsRepository {
  Future<DeliveryVehicle> readCourierVehicle();
  Future<void> writeCourierVehicle(DeliveryVehicle vehicle);
}

final class SharedPreferencesUserSettingsRepository
    implements UserSettingsRepository {
  static const selectedCourierVehicleKey = 'selected_courier_vehicle';
}
```

Enum label, asset path and fallback emoji остаются presentation metadata через extension или отдельный mapper; storage сохраняет только стабильное enum name.

## Cubit Contract

```dart
final class UserSettingsState extends Equatable {
  final DeliveryVehicle selectedCourierVehicle;
  final bool isLoaded;
  final String? errorCode;
}

final class UserSettingsCubit extends Cubit<UserSettingsState> {
  UserSettingsCubit(this._repository);

  Future<void> load();
  Future<void> selectCourierVehicle(DeliveryVehicle vehicle);
}
```

`selectCourierVehicle` оптимистично обновляет state, затем сохраняет значение. При ошибке состояние откатывается и выставляет `SETTINGS_WRITE_FAILED`. Cubit создаётся один раз над корневым navigator и вызывает `load()` при старте приложения.

## Integration Points

- Добавить `shared_preferences` в `apps/customer_mobile/pubspec.yaml`.
- Создать repository, enum и Cubit в `apps/customer_mobile/lib/features/profile/`.
- В `profile_screen.dart` добавить секцию «Транспорт курьера» с radio/check selection из `DeliveryVehicle.values`; выбор вызывает `UserSettingsCubit.selectCourierVehicle`.
- В `order_status_tracker.dart` удалить `_selectedVehicle` и локальный picker; получать значение через `context.select<UserSettingsCubit, DeliveryVehicle>`.
- Существующий `precacheImage` для всех WebP-ассетов сохраняется; рендер использует выбранный глобальный skin и fallback emoji.
- До завершения `load()` tracker безопасно показывает `yellowScooter`, не блокируя первый кадр.

## Failure And Migration Rules

- Неизвестное сохранённое значение не вызывает exception: возвращается default и storage перезаписывается корректным значением.
- Ключ не привязан к customer id и сохраняет UI-предпочтение после logout.
- При будущей серверной синхронизации локальное значение остаётся offline cache; разрешение конфликтов оформляется отдельным решением.

## Consequences

Положительные: выбор переживает restart, один источник состояния для профиля и tracker, минимальная новая зависимость.

Отрицательные: async initialization и ошибки записи требуют явных состояний; настройка пока не синхронизируется между устройствами.

## Alternatives Rejected

- StatefulWidget-only: настройка не персистентна.
- HydratedBloc: лишняя инфраструктура для одного ключа и новая схема сериализации.
- Secure Storage: транспорт не является секретом; storage дороже и семантически неверен.

## Test Contract

- repository: missing/valid/unknown value и write failure;
- Cubit: load default, load persisted, optimistic update, rollback;
- profile: выбранный пункт отмечен и сохраняется;
- tracker: использует Cubit value после rebuild и fallback до load;
- widget precache: отсутствие regressions для четырёх локальных WebP.

## Review Criteria

Пересмотреть при появлении нескольких настроек со сложной миграцией, серверной синхронизации или требования шифрования.

## Related Documents

ADR-1606 Flutter as Cross-Platform Framework

ADR-1608 Clean Architecture and Modular Monolith Ready

ADR-1615 Realtime Order Timeline

UI-803 Component Library

END OF DOCUMENT
