---
Document ID: ADR-1618

Document Name: ADR - KITCHEN POS ARCHITECTURE

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

# ADR - KITCHEN POS ARCHITECTURE

## Status

Accepted

## Context

`apps/kds` уже содержит Flutter/Web интерфейс с тремя колонками, `KdsOrdersBloc`, карточками, таймерами, fake/remote repositories и моделью смены. Текущая remote-интеграция использует общие незащищённые Orders endpoints, передаёт `branchId`, `cookId` и `shiftId` от клиента и работает polling-first. Backend-модуль кухни и terminal identity отсутствуют.

В dev harness фоновые jobs автоматически переводят `CONFIRMED -> COOKING -> READY`. Это противоречит целевой модели, в которой кухонный терминал владеет обоими переходами.

## Decision

Создать bounded context `kitchen` в backend и развивать существующий `apps/kds` как Kitchen POS для планшетов и web-терминалов. Авторизация выполняется от имени терминала с ролью `KITCHEN`; персональная роль повара и смена остаются отдельными audit-атрибутами.

Кухня является единственным production-владельцем переходов:

```text
CONFIRMED -> COOKING -> READY
```

`NEW` не показывается кухне. `READY -> COMPLETED` не является действием кухни: доставку завершает courier, выдачу dine-in/takeaway - POS или операторский контур.

## Terminal Identity And Authorization

```ts
type KitchenTokenPayload = {
  sub: string;       // kitchenTerminalId
  branchId: string;
  role: 'KITCHEN';
  type: 'access';
  iat: number;
  exp: number;
};

type KitchenPinAuthDto = {
  terminalCode: string;
  pin: string;       // exactly 4 digits
};

type KitchenAuthResponseDto = {
  token: string;
  terminal: { id: string; code: string; name: string; branchId: string };
};
```

`POST /kitchen/auth/pin` проверяет bcrypt hash PIN, active flag и branch availability, затем выдаёт подписанный access JWT не дольше одной рабочей смены. PIN и JWT запрещено логировать.

```prisma
model KitchenTerminal {
  id        String   @id @default(uuid()) @db.Uuid
  code      String   @unique
  name      String
  pinHash   String   @map("pin_hash")
  branchId  String   @map("branch_id") @db.Uuid
  isActive  Boolean  @default(true) @map("is_active")
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt DateTime @updatedAt @map("updated_at") @db.Timestamptz(6)

  branch Branch @relation(fields: [branchId], references: [id], onDelete: Restrict)

  @@index([branchId, isActive], map: "idx_kitchen_terminals_branch_id_is_active")
  @@map("kitchen_terminals")
}
```

`KitchenJwtAuthGuard` принимает только `role: KITCHEN` и заполняет request identity. Все kitchen endpoints определяют `terminalId` и `branchId` строго из JWT. Legacy `branchId` query допускается только на период совместимости и обязан совпадать с JWT claim.

Native tablet хранит JWT в `flutter_secure_storage`. Web-терминал хранит token только в памяти/session storage, очищает его при закрытии browser session и работает исключительно через HTTPS с CSP. Общий persistent browser storage для JWT запрещён.

## Kitchen API

### Active Board Snapshot

`GET /kitchen/orders/active`

```ts
type KitchenOrderStatus = 'CONFIRMED' | 'COOKING' | 'READY';

type KitchenOrderItemDto = {
  id: string;
  name: string;
  quantity: number;
  comment: string | null;
  modifiers: Array<{ id: string; name: string; quantity: number }>;
};

type KitchenOrderDto = {
  id: string;
  orderNumber: string;
  version: number;
  status: KitchenOrderStatus;
  type: 'DINE_IN' | 'TAKEAWAY' | 'DELIVERY';
  tableNumber: string | null;
  comment: string | null;
  confirmedAt: string;
  cookingStartedAt: string | null;
  readyAt: string | null;
  items: KitchenOrderItemDto[];
};

type KitchenBoardSnapshotDto = {
  serverTime: string;
  orders: KitchenOrderDto[];
};
```

Snapshot возвращает только активные заказы филиала из JWT, сортировка внутри каждой колонки FIFO по timestamp входа в текущий статус. `serverTime` используется для вычисления clock offset и устойчивых таймеров.

### Status Mutation

`PATCH /kitchen/orders/{orderId}/status`

```ts
type UpdateKitchenOrderStatusDto = {
  status: 'COOKING' | 'READY';
  expectedVersion: number;
  cookId?: string;
  shiftId?: string;
};
```

Rules:

- `CONFIRMED -> COOKING`: атомарно записать `cookingStartedAt = serverNow`;
- `COOKING -> READY`: атомарно записать `readyAt = serverNow`;
- order branch обязан совпадать с JWT branch;
- `expectedVersion` обеспечивает optimistic concurrency и увеличивается после mutation;
- `cookId`/`shiftId` являются audit metadata, не источником авторизации; если переданы, backend проверяет активную смену и принадлежность branch;
- `403 ORDER_BRANCH_FORBIDDEN`, `409 ORDER_VERSION_CONFLICT`, `409 INVALID_ORDER_STATUS_TRANSITION` возвращаются как стабильные error codes;
- status transition, timestamps и `OrderStatusHistory` фиксируются одной PostgreSQL transaction.

В `Order` добавляются nullable `confirmedAt`, `cookingStartedAt`, `readyAt`. Исторические активные заказы могут получить значения из первой соответствующей `OrderStatusHistory`; при отсутствии используется `updatedAt` с audit marker миграции.

## Realtime Contract

`GET /kitchen/stream` возвращает branch-scoped SSE после `KitchenJwtAuthGuard`.

```ts
type KitchenOrderEventV1 = {
  eventId: string;
  eventType: 'kitchen.order.upserted' | 'kitchen.order.removed';
  eventVersion: 1;
  occurredAt: string;
  orderId: string;
  orderVersion: number;
  order: KitchenOrderDto | null;
};
```

Flow:

```text
committed order transition
  -> kitchen event publisher
  -> Redis Pub/Sub channel kitchen.branch.{branchId}
  -> Kitchen SSE Gateway
  -> KdsOrdersBloc
```

Redis Pub/Sub используется для realtime fan-out, а не как durable event bus. PostgreSQL snapshot остаётся источником истины. RabbitMQ сохраняет роль межсервисного event bus по ADR-1603.

Delivery rules:

- первое SSE-сообщение - snapshot или stream-ready marker;
- client применяет только событие с `orderVersion` выше локальной версии;
- `COMPLETED`/`CANCELLED` отправляются как `removed`;
- reconnect использует exponential backoff с jitter до 30 секунд;
- после reconnect клиент сначала запрашивает snapshot;
- после трёх неудачных reconnect включается foreground polling каждые 15 секунд;
- после восстановления SSE polling останавливается;
- heartbeat не реже одного раза в 20 секунд.

## Production Status Ownership

Dev status timers и `SEND_TO_KITCHEN_JOB` не переводят production-заказ в `COOKING` или `READY`.

- payment/order processing переводит валидный заказ в `CONFIRMED`;
- `CONFIRMED` публикуется в kitchen channel;
- только authenticated kitchen mutation начинает приготовление;
- автоматические timers разрешены лишь при явном `KDS_STATUS_EMULATION_ENABLED=true` вне production;
- включение emulation в production считается configuration error и должно останавливать startup.

## KDS Client Architecture

Сохраняются `flutter_bloc`, repository contracts, `get_it` и существующая responsive board. Remote mode становится auth/SSE-first; fake repositories остаются только demo/test dependency.

```dart
sealed class KitchenAuthState {}
final class KitchenAuthRestoring extends KitchenAuthState {}
final class KitchenUnauthenticated extends KitchenAuthState {}
final class KitchenAuthenticated extends KitchenAuthState {
  final KitchenSession session;
}

final class KdsOrdersState {
  final List<KdsOrder> orders;
  final KdsConnectionState connection;
  final Set<String> mutatingOrderIds;
  final Duration serverClockOffset;
}
```

One configured Dio instance добавляет Bearer token во все protected REST/SSE calls. `401` выполняет single-flight logout; mutation автоматически не повторяется.

## Board And Card Rules

| Column | Status | Timer source | Primary action |
|---|---|---|---|
| «Новые» | `CONFIRMED` | `confirmedAt` | «Начать готовить» |
| «Готовятся» | `COOKING` | `cookingStartedAt` | «Готово» |
| «Готовы» | `READY` | `readyAt` | отсутствует |

Card содержит:

- крупный номер заказа;
- delivery/takeaway/dine-in badge и номер стола при наличии;
- позиции, количество, модификаторы и line comment;
- общий комментарий клиента;
- status timer, вычисленный по server timestamp;
- одну primary action размером не менее 48 px.

Широкий tablet/web viewport показывает три колонки одновременно. Узкий viewport использует tabs с counters. Внутри колонок применяется FIFO; просроченные карточки меняют accent, но не порядок.

Mutation выполняется optimistic: карточка перемещается сразу и блокируется до ответа. При conflict/error выполняются rollback, snackbar с error code и обязательный snapshot refresh. Offline mutation queue запрещена.

## New Order Sound

Ввести `KitchenAlertService` и локальный короткий asset через `audioplayers`. Звук не зависит от сети и не содержит речи.

Rules:

- звук только при первом появлении заказа в `CONFIRMED` после initial snapshot;
- дедупликация по `orderId + orderVersion`;
- несколько заказов за 500 ms дают один сигнал;
- reconnect snapshot не воспроизводит звук повторно;
- terminal предоставляет mute toggle с заметным muted indicator;
- Web требует одно пользовательское действие «Включить звук» при открытии смены из-за browser autoplay policy;
- ошибка audio playback не влияет на board и сопровождается visual highlight.

## Security And Observability

- terminal не может читать или менять заказы другого branch;
- backend не доверяет `branchId`, `terminalId`, `cookId` или timestamps клиента;
- customer phone/address и payment details не входят в Kitchen DTO;
- comments проходят безопасный text rendering и length limits;
- audit сохраняет terminalId, verified cookId/shiftId, previous/new status и server timestamp;
- metrics: connected terminals, SSE reconnects, snapshot latency, transition conflicts, order age by status, alert playback failure;
- JWT, PIN и customer comments не попадают в logs/metrics.

## Consequences

Положительные: строгая изоляция филиалов, один владелец kitchen transitions, мгновенное обновление нескольких терминалов, корректные таймеры и безопасное восстановление после SSE gaps.

Отрицательные: новый terminal identity и migration; Redis/SSE operational complexity; web audio требует user gesture; существующий polling-first и auto-transition dev harness необходимо переработать.

## Alternatives Rejected

- Роль `COOK` как terminal role: смешивает shared device identity и личность сотрудника.
- Общие `/orders` endpoints: не обеспечивают узкую kitchen authorization boundary.
- Передавать `branchId` от UI: допускает горизонтальное повышение доступа.
- Только polling: задерживает новые заказы и создаёт постоянную нагрузку.
- Только SSE: не восстанавливает пропущенные ephemeral events.
- Таймер от локального момента render: расходится между терминалами и сбрасывается после refresh.
- `READY -> COMPLETED` из KDS: смешивает приготовление с выдачей/доставкой.

## Kimi k3 Implementation Plan

### Phase 0 - Contract And Schema

- `docs/07-api/709-kitchen-api.md`: описать auth, snapshot, SSE, mutation DTO, errors и JWT scope до реализации.
- `services/backend/prisma/schema.prisma`: добавить `KitchenTerminal` и timestamps `confirmedAt`, `cookingStartedAt`, `readyAt` в `Order`.
- `services/backend/prisma/migrations/<timestamp>_add_kitchen_terminals_and_order_timestamps/migration.sql`: таблица, indexes, columns и backfill из `OrderStatusHistory`.
- `services/backend/src/modules/orders/domain/order-status-machine.ts`: сохранить только допустимые production transitions; не добавлять bypass.
- Проверка: `prisma validate`, migration dry run, OpenAPI/DTO naming review.

### Phase 1 - Kitchen Backend Boundary

- `services/backend/src/modules/kitchen/kitchen.module.ts`: wiring Prisma, JWT, Redis publisher и controller.
- `services/backend/src/modules/kitchen/kitchen.controller.ts`: четыре утверждённых endpoints.
- `services/backend/src/modules/kitchen/kitchen.service.ts`: auth, branch-scoped snapshot, transactional transitions и audit validation.
- `services/backend/src/modules/kitchen/kitchen-events.service.ts`: Redis Pub/Sub adapter и SSE heartbeat/snapshot recovery.
- `services/backend/src/modules/kitchen/kitchen.types.ts`: token identity и event envelope.
- `services/backend/src/modules/kitchen/kitchen.config.ts`: JWT TTL, bcrypt rounds, Redis channel prefix и emulation guard.
- `services/backend/src/modules/kitchen/guards/kitchen-jwt-auth.guard.ts`: verify signature, expiry, role/type and active terminal.
- `services/backend/src/modules/kitchen/dto/kitchen-auth.dto.ts`, `kitchen-order-status.dto.ts`: strict validation, no client branch/terminal fields.
- `services/backend/src/app.module.ts`: подключить `KitchenModule`.
- `services/backend/src/modules/queues/order-processing.processor.ts`: production flow заканчивается на `CONFIRMED`; timers только под non-production flag.
- Проверка: cross-branch 403, stale version 409, invalid transition 409, duplicate events idempotent.

### Phase 2 - KDS Auth And Transport

- `apps/kds/pubspec.yaml`: добавить `flutter_secure_storage`, `audioplayers` и локальный alert asset.
- `apps/kds/lib/core/storage/kitchen_token_storage.dart`: native secure storage и conditional web session storage.
- `apps/kds/lib/core/network/api_client.dart`: configured Dio, Bearer interceptor, 401 single-flight callback и SSE byte stream.
- `apps/kds/lib/features/auth/bloc/kitchen_auth_cubit.dart`: restore/login/logout/session expiry.
- `apps/kds/lib/features/auth/view/kitchen_login_screen.dart`: terminal code + 4-digit PIN.
- `apps/kds/lib/features/kds/data/kds_orders_repository.dart`: перейти на `/kitchen/*`, убрать client-controlled branch.
- `apps/kds/lib/features/kds/data/kitchen_events_client.dart`: typed SSE parser и reconnect boundary.
- `apps/kds/lib/app/injection.dart`: production graph с auth storage, ApiClient, remote repository и alert service; fake graph только при explicit demo flag.
- `apps/kds/lib/app/app.dart`: root auth gate и cleanup subscriptions при logout.

### Phase 3 - Realtime Board And Sound

- `apps/kds/lib/features/kds/data/kds_order_models.dart`: только CONFIRMED/COOKING/READY projection, version и server timestamps.
- `apps/kds/lib/features/kds/bloc/kds_orders_event.dart`: snapshot, SSE upsert/remove, reconnect, poll tick и mutation events.
- `apps/kds/lib/features/kds/bloc/kds_orders_state.dart`: connection, clock offset, fresh IDs и multiple mutation IDs.
- `apps/kds/lib/features/kds/bloc/kds_orders_bloc.dart`: snapshot-first, SSE, dedupe, 15 s fallback polling, optimistic rollback и lifecycle cleanup.
- `apps/kds/lib/features/kds/view/kds_screen.dart`: «Новые / Готовятся / Готовы», connection/mute indicators и sound unlock action for Web.
- `apps/kds/lib/features/kds/view/widgets/order_card.dart`: удалить NEW и READY actions; labels «Начать готовить» / «Готово».
- `apps/kds/lib/features/kds/view/widgets/order_delay_timer.dart`: считать от status-specific server timestamp и clock offset.
- `apps/kds/lib/core/audio/kitchen_alert_service.dart`: asset preload, coalescing, mute и playback failure handling.
- `apps/kds/assets/audio/new_order.mp3`: короткий локальный сигнал с подтверждённой лицензией.

### Phase 4 - Verification And Rollout

- Backend tests: auth, inactive terminal, role mismatch, branch isolation, version conflict, transition transaction, SSE filtering/heartbeat and production emulation guard.
- Flutter unit tests: SSE parser, dedupe, reconnect-to-polling, rollback, timer offset, alert coalescing and initial-snapshot silence.
- Widget tests: three-column/tablet layout, narrow tabs, modifiers/comments, one-tap actions, mute/audio unlock and connection states.
- Integration: `CONFIRMED` appears once with sound -> `COOKING` timer starts -> `READY` wait timer starts -> courier feed receives order.
- Commands: backend targeted Jest tests, full backend tests and TypeScript check; `flutter analyze` and `flutter test` in `apps/kds`.
- Rollout: one test branch, two simultaneous terminals, Redis/SSE interruption drill, cross-branch negative test, then per-branch feature flag enablement.

## Review Criteria

Пересмотреть при station-specific routing, parallel preparation of order items, bump-screen hardware, printer integration, offline-first mutations or guaranteed event replay.

## Related Documents

ADR-1603 Event-Driven Architecture

ADR-1605 NestJS as Backend Framework

ADR-1606 Flutter as Cross-Platform Framework

ADR-1608 Clean Architecture and Modular Monolith Ready

ADR-1609 API-First and Contract-First Development

ADR-1615 Realtime Order Timeline

ADR-1617 Courier Mobile Architecture

API-709 Kitchen API

UI-807 Kitchen Display System UX

SEC-1103 Authentication and Session Security

END OF DOCUMENT
