---
Document ID: ADR-1617

Document Name: ADR - COURIER MOBILE ARCHITECTURE

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

# ADR - COURIER MOBILE ARCHITECTURE

## Status

Accepted

## Context

`apps/courier_mobile` уже содержит Flutter-клиент с `AuthCubit`, `OrdersCubit`, fake/remote repositories и базовыми экранами доставки. Текущая реализация хранит JWT внутри JSON-сессии в `shared_preferences`, задаёт Authorization напрямую в Dio и обновляет список только вручную. Background location отсутствует.

Backend выдаёт courier JWT с `sub`, `phone`, `branchId`, `role: COURIER`, `type: access` и TTL 12 часов. ADR определяет целевую архитектуру клиента и обязательные backend prerequisites.

## Decision

Развивать приложение как feature-oriented Flutter-клиент с `flutter_bloc`, repository interfaces и одним авторизованным Dio client. JWT хранить только в `flutter_secure_storage`. Realtime получать через SSE, а polling использовать только как fallback. Геолокацию отправлять только для собственного заказа в `ON_WAY`.

## Authentication And Session

```dart
sealed class CourierAuthState {}
final class CourierAuthRestoring extends CourierAuthState {}
final class CourierUnauthenticated extends CourierAuthState {}
final class CourierAuthenticating extends CourierAuthState {}
final class CourierAuthenticated extends CourierAuthState {
  final CourierSession session;
}
final class CourierAuthFailure extends CourierAuthState {
  final String code;
}

abstract interface class CourierTokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

final class CourierAuthCubit extends Cubit<CourierAuthState> {
  Future<void> restore();
  Future<void> login({required String phone, required String pin});
  Future<void> logout();
  Future<void> sessionExpired();
}
```

Rules:

- phone нормализуется в E.164; PIN содержит ровно четыре цифры;
- `POST /couriers/auth/pin` не получает `branchId`: identity и branch возвращаются сервером;
- JWT хранится под versioned key `courier_access_token_v2` в `flutter_secure_storage`;
- PIN, JWT и координаты запрещено писать в logs, analytics и crash breadcrumbs;
- legacy `courier_session_v1` читается один раз, JWT переносится в secure storage, затем весь legacy key удаляется;
- restore является async: отсутствующий, повреждённый или истёкший token очищается и ведёт в `CourierUnauthenticated`;
- logout останавливает SSE/location subscriptions, очищает token и только затем показывает login screen.

## Authorized HTTP Client

```dart
abstract interface class AccessTokenProvider {
  Future<String?> readAccessToken();
}

abstract interface class UnauthorizedHandler {
  Future<void> onUnauthorized();
}

final class CourierAuthInterceptor extends Interceptor {
  // Adds Authorization: Bearer <token> to protected requests.
  // A 401 triggers one single-flight session invalidation.
}
```

Один configured Dio instance используется REST repositories и SSE client. Login endpoint исключён из token injection. `401` очищает session один раз и переводит root auth gate на login; запрос автоматически не повторяется. `403` отображается как недостаток прав и не уничтожает валидную session. JWT не передаётся query-параметром.

## Backend Prerequisites

До подключения быстрых действий и геотрекинга backend должен предоставить следующие guarded contracts.

### Courier Order Transition

`PATCH /couriers/orders/{orderId}/status`

```ts
type UpdateCourierOrderStatusDto = {
  status: 'READY' | 'ON_WAY' | 'COMPLETED';
};
```

`courierId` и `branchId` берутся только из verified JWT и отсутствуют в body/query.

- unassigned `READY` + target `READY`: атомарно назначить заказ courier из JWT (`CLAIM`);
- own `READY` + target `ON_WAY`: начать доставку;
- own `ON_WAY` + target `COMPLETED`: завершить доставку;
- чужой заказ: `403 ORDER_NOT_ASSIGNED_TO_COURIER`;
- гонка claim: `409 ORDER_ALREADY_ASSIGNED`;
- второй активный claim при принятой модели одного активного заказа: `409 COURIER_HAS_ACTIVE_ORDER`;
- неверный переход: `409 INVALID_ORDER_STATUS_TRANSITION`.

Общий незащищённый `PATCH /orders/{id}/status` не используется courier client. Его staff authorization является отдельным backend security requirement.

### Courier Location

`POST /couriers/location`

```ts
type ReportCourierLocationDto = {
  orderId: string;
  latitude: number;
  longitude: number;
  accuracyMeters: number;
  capturedAt: string;
};
```

Ответ: `202 Accepted`. Сервер извлекает courier/branch из JWT и принимает координату только если заказ назначен этому courier и имеет `ON_WAY`. Проверяются диапазоны координат, `accuracyMeters > 0`, допустимый clock skew и rate limit. Сырые координаты не логируются.

`GET /couriers/orders/active` и `/couriers/stream` также ограничиваются branch из JWT; переданный legacy `branchId` должен совпадать с claim либо игнорироваться сервером.

## Orders State

```dart
enum CourierOrdersTab { available, mine }

final class CourierOrdersState {
  final List<CourierOrder> orders;
  final CourierOrdersTab tab;
  final String? mutatingOrderId;
  final RealtimeConnectionState realtime;
}

final class CourierOrdersCubit extends Cubit<CourierOrdersState> {
  Future<void> start();
  Future<void> refresh();
  Future<void> claim(String orderId);
  Future<void> startDelivery(String orderId);
  Future<void> completeDelivery(String orderId);
  Future<void> stop();
}
```

`OrdersListScreen` содержит вкладки:

- «Доступные заказы филиала»: unassigned delivery orders в `COOKING` или `READY`; claim доступен только для `READY`;
- «Мой активный заказ»: собственный assigned order в `READY` или `ON_WAY`.

Actions:

| UI action | Request | Optimistic result |
|---|---|---|
| «Взять доставку» | `READY` | order перемещается в «Мой активный заказ» |
| «В пути» | `ON_WAY` | запускается location tracking |
| «Доставлен» | `COMPLETED` | tracking останавливается, order удаляется из active |

На mutation кнопки заказа блокируются. При `409` или network error выполняются rollback и немедленный refresh. Завершение требует confirmation dialog.

## Realtime And Polling

- после initial REST snapshot открыть authorized SSE `/couriers/stream`;
- client фильтрует/дедуплицирует события по `orderId` и `orderVersion`, но security filtering выполняет сервер;
- reconnect: exponential backoff с jitter, максимум 30 секунд;
- после разрыва всегда выполнять REST refresh перед повторным SSE connect;
- если SSE недоступен после трёх попыток, включить polling каждые 30 секунд только в foreground;
- при восстановлении SSE polling остановить;
- на app resume выполнить немедленный refresh;
- pull-to-refresh остаётся ручным recovery path.

SSE читается как Dio byte stream с Authorization header. Browser `EventSource` не используется.

## Background Location

Использовать `geolocator` и platform-specific `LocationSettings`; отдельный постоянно работающий Dart service plugin не вводится.

Lifecycle:

```text
own order becomes ON_WAY -> permission gate -> start position stream
position -> quality check -> throttle/distance gate -> POST /couriers/location
COMPLETED/logout/lost ownership/permission revoked -> cancel stream immediately
```

Send gate:

- отправить, если прошло 15 секунд с последней принятой к отправке точки;
- либо отправить при смещении не менее 30 метров;
- для distance-trigger действует hard minimum 3 секунды против GPS jitter;
- точки с invalid coordinates или `accuracyMeters > 100` не отправлять;
- при offline хранить только последнюю точку, удалить её через 2 минуты;
- сетевые повторы используют backoff и не переживают завершение заказа.

Permission policy:

1. Проверить включённость location services и текущий grant.
2. Запросить `While in Use` после явного действия «В пути».
3. Объяснить пользу background tracking и отдельно запросить `Always`, когда ОС это допускает.
4. При `While in Use` продолжать доставку с foreground-only tracking и видимым предупреждением.
5. При denied/permanently denied не повторять prompt циклически; показать действие перехода в system settings.

Android использует foreground location service с постоянным notification только во время `ON_WAY`. iOS включает Background Modes / Location updates и системный background indicator. ОС может приостановить или завершить приложение; backend и клиент не предполагают гарантированный интервал доставки каждой точки.

## Platform Configuration

Android:

- minimum SDK 23 из-за выбранного secure storage;
- permissions: coarse/fine location, background location, foreground service и foreground service location;
- исключить secure-storage данные из backup;
- notification сообщает номер активного заказа и позволяет вернуться в приложение.

iOS:

- `NSLocationWhenInUseUsageDescription`;
- `NSLocationAlwaysAndWhenInUseUsageDescription`;
- `UIBackgroundModes = location`;
- Keychain Sharing configuration, требуемая `flutter_secure_storage`;
- purpose strings явно связывают геолокацию с активной доставкой.

## Privacy And Observability

- tracking выключен вне `ON_WAY` и после logout;
- клиент не хранит историю маршрута;
- metrics содержат только send success/failure, latency, permission state и SSE reconnect count без координат/JWT;
- server retention и доступ диспетчера определяются отдельной data-retention policy;
- весь transport только через TLS.

## Consequences

Положительные: token защищён платформенным storage, branch/courier нельзя подменить клиентом, UI восстанавливается после SSE gaps, геолокация ограничена активной доставкой.

Отрицательные: minimum Android SDK становится 23; background permissions требуют platform configuration и review магазинов; iOS/Android не гарантируют точный интервал в background; необходимы два backend courier endpoints.

## Alternatives Rejected

- JWT в `shared_preferences`: секрет хранится в plaintext application storage.
- Authorization header, изменяемый repository вручную: легко получить запрос без token и нет единой обработки 401.
- Только polling: лишний трафик и задержка обновления заказов.
- Только SSE: отсутствует recovery при длительной недоступности stream.
- Постоянный location tracking: нарушает принцип минимизации данных и расходует батарею.

## Kimi k3 Implementation Plan

### Phase 0 - Backend contract gate

- `services/backend/src/modules/couriers/couriers.controller.ts`: добавить guarded status/location routes и получать identity из request, установленного guard.
- `services/backend/src/modules/couriers/couriers.service.ts`: атомарный claim, ownership/branch checks и разрешённые transitions.
- `services/backend/src/modules/couriers/dto/update-courier-order-status.dto.ts`: status-only DTO.
- `services/backend/src/modules/couriers/dto/report-courier-location.dto.ts`: location validation DTO.
- Обновить courier controller/service tests; не принимать `courierId` или `branchId` от клиента.

### Phase 1 - Secure auth and Dio

- `apps/courier_mobile/pubspec.yaml`: добавить `flutter_secure_storage` и `geolocator`.
- `apps/courier_mobile/lib/core/storage/courier_auth_storage.dart`: secure token v2, one-time legacy migration, async read/clear.
- `apps/courier_mobile/lib/core/network/courier_auth_interceptor.dart`: Bearer injection и single-flight 401 callback.
- `apps/courier_mobile/lib/data/models/courier_session.dart`: исключить сериализацию JWT в SharedPreferences.
- `apps/courier_mobile/lib/data/repositories/remote_courier_repository.dart`: принять configured Dio; убрать mutable `token` setter и branch/courier parameters из protected writes.
- `apps/courier_mobile/lib/features/auth/bloc/auth_cubit.dart`: restore/login/logout/sessionExpired; token expiry check.
- `apps/courier_mobile/lib/app.dart`: собрать storage, interceptor, repository и lifecycle-safe auth gate.

### Phase 2 - Orders realtime

- `apps/courier_mobile/lib/data/repositories/courier_repository.dart`: claim/start/complete и event stream contracts.
- `apps/courier_mobile/lib/data/repositories/courier_events_client.dart`: Dio SSE parser, reconnect boundary и typed events.
- `apps/courier_mobile/lib/features/orders/bloc/orders_cubit.dart`: snapshot + SSE + polling fallback, optimistic mutation/rollback.
- `apps/courier_mobile/lib/features/orders/bloc/orders_state.dart`: available/mine projection и realtime connection state.
- `apps/courier_mobile/lib/features/orders/view/courier_orders_screen.dart`: две утверждённые вкладки и connection indicator.
- `apps/courier_mobile/lib/features/orders/view/delivery_detail_screen.dart`: claim, start, complete actions с confirmation.

### Phase 3 - Location

- `apps/courier_mobile/lib/features/location/data/courier_location_repository.dart`: `POST /couriers/location`.
- `apps/courier_mobile/lib/features/location/bloc/location_tracking_cubit.dart`: permission/service state, ON_WAY lifecycle, throttle/distance gate и latest-point retry.
- `apps/courier_mobile/android/app/src/main/AndroidManifest.xml`: permissions и foreground-service configuration.
- `apps/courier_mobile/android/app/build.gradle.kts`: minimum SDK 23.
- `apps/courier_mobile/ios/Runner/Info.plist`: usage descriptions и background mode.
- `apps/courier_mobile/ios/Runner.xcodeproj/project.pbxproj`: Background Modes и Keychain capability settings.

### Phase 4 - Verification

- Unit: token migration, 401 single-flight, SSE parsing/reconnect, partitioning, rollback, location gates.
- Widget: PIN validation, auth gate, tabs, disabled/loading actions, permission warnings.
- Integration: login -> claim -> ON_WAY -> coordinate -> COMPLETED -> tracking stopped.
- Commands: `flutter analyze` and `flutter test` in `apps/courier_mobile`; backend targeted tests plus `pnpm --filter backend test` and TypeScript check.
- Manual devices: Android foreground notification/background movement; iOS While in Use, Always, denied and terminated/suspended behavior.

## Review Criteria

Пересмотреть при refresh tokens, нескольких одновременных доставках, turn-by-turn navigation, guaranteed background delivery или server-driven tracking frequency.

## Related Documents

ADR-1605 NestJS as Backend Framework

ADR-1606 Flutter as Cross-Platform Framework

ADR-1608 Clean Architecture and Modular Monolith Ready

ADR-1609 API-First and Contract-First Development

ADR-1615 Realtime Order Timeline

SEC-1103 Authentication and Session Security

INT-1003 Maps and Geolocation Integrations

UI-808 Courier Mobile App UX

END OF DOCUMENT
