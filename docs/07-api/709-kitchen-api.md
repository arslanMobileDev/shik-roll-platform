---
Document ID: API-709

Document Name: KITCHEN API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: September 2026

Classification: Internal
---

# KITCHEN API

## Purpose

Определяет REST/SSE контракт Kitchen POS (ADR-1618): аутентификация кухонного терминала, snapshot активной доски филиала, realtime-поток событий и kitchen-owned переходы статусов `CONFIRMED -> COOKING -> READY`.

`NEW` кухне не показывается. `READY -> COMPLETED` не является действием кухни: доставку завершает courier, выдачу dine-in/takeaway — POS или операторский контур.

---

# Base Endpoint

```text
/kitchen
```

---

# Authentication And JWT Scope

Терминал аутентифицируется shared device identity с ролью `KITCHEN`. Все защищённые endpoints определяют `terminalId` и `branchId` строго из JWT — клиентские `branchId`/`terminalId`/`cookId` не являются источником авторизации.

```ts
type KitchenTokenPayload = {
  sub: string;       // kitchenTerminalId
  branchId: string;
  role: 'KITCHEN';
  type: 'access';
  iat: number;
  exp: number;
};
```

`KitchenJwtAuthGuard` проверяет подпись, срок, `role: KITCHEN`, `type: access` и активность терминала в БД на каждый запрос: деактивированный терминал теряет доступ немедленно, даже с валидным JWT.

Токены других bounded contexts (`CUSTOMER`, `COURIER`) отклоняются. PIN и JWT запрещено логировать.

## POST /kitchen/auth/pin

Purpose

Аутентификация терминала по коду и 4-значному PIN (bcrypt). Публичный endpoint.

Request

```ts
type KitchenPinAuthDto = {
  terminalCode: string;
  pin: string;       // exactly 4 digits
};
```

Response 200

```ts
type KitchenAuthResponseDto = {
  token: string;
  tokenType: 'Bearer';
  expiresInSeconds: number;   // KITCHEN_TOKEN_TTL_SECONDS, default 12 h
  terminal: { id: string; code: string; name: string; branchId: string };
};
```

Errors

- `401 UNAUTHORIZED` — неверный код или PIN (uniform message, не раскрывает существование кода); терминал деактивирован
- `401 TERMINAL_BRANCH_UNAVAILABLE` — филиал терминала недоступен
- `400 VALIDATION_ERROR` — формат полей

---

# Kitchen Orders

## GET /kitchen/orders/active

Purpose

Snapshot активной доски филиала из JWT: заказы в статусах `CONFIRMED`, `COOKING`, `READY`, FIFO по timestamp входа в текущий статус. `serverTime` используется клиентом для clock offset и устойчивых таймеров.

Authentication

Bearer JWT (`KITCHEN`)

Response 200

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

DTO намеренно не содержит телефон/адрес клиента и платёжные данные.

Errors

- `401 UNAUTHORIZED` / `401 TOKEN_INVALID` / `401 TERMINAL_INACTIVE`

---

## PATCH /kitchen/orders/{orderId}/status

Purpose

Kitchen-driven переход статуса: `CONFIRMED -> COOKING` (атомарно пишет `cookingStartedAt = serverNow`) или `COOKING -> READY` (атомарно пишет `readyAt = serverNow`). Status transition, timestamps и `OrderStatusHistory` фиксируются одной PostgreSQL transaction.

Authentication

Bearer JWT (`KITCHEN`)

Request

```ts
type UpdateKitchenOrderStatusDto = {
  status: 'COOKING' | 'READY';
  expectedVersion: number;   // optimistic concurrency
  cookId?: string;           // audit metadata, не авторизация
  shiftId?: string;          // audit metadata, не авторизация
};
```

Response 200

`KitchenOrderDto` с инкрементированным `version`.

Errors

- `401 UNAUTHORIZED` / `401 TOKEN_INVALID` / `401 TERMINAL_INACTIVE`
- `404 ORDER_NOT_FOUND` — заказ не существует
- `403 ORDER_BRANCH_FORBIDDEN` — заказ другого филиала
- `409 ORDER_VERSION_CONFLICT` — `expectedVersion` устарела (refresh + retry)
- `409 INVALID_ORDER_STATUS_TRANSITION` — текущий статус не является источником перехода
- `400 VALIDATION_ERROR` — формат полей

---

# Realtime

## GET /kitchen/stream

Purpose

Branch-scoped SSE поток (ADR-1618 realtime contract). Fan-out через Redis Pub/Sub channel `kitchen.branch.{branchId}` (in-process bus без Redis). Pub/Sub — realtime fan-out, не durable event bus: источник истины — PostgreSQL snapshot.

Authentication

Bearer JWT (`KITCHEN`)

Events

```ts
type KitchenOrderEventV1 = {
  eventId: string;
  eventType: 'kitchen.order.upserted' | 'kitchen.order.removed';
  eventVersion: 1;
  occurredAt: string;
  orderId: string;
  orderVersion: number;
  order: KitchenOrderDto | null;   // null для removed
};
```

- SSE `event:` = `eventType`; `COMPLETED`/`CANCELLED`/`ON_WAY` отправляются как `removed`
- heartbeat `event: heartbeat` каждые 15 s (`KITCHEN_SSE_HEARTBEAT_MS`, контракт: не реже 20 s) с `{ serverTime }`
- клиент применяет только события с `orderVersion` выше локальной; первое состояние — через `GET /kitchen/orders/active`

Client recovery

- reconnect: exponential backoff с jitter до 30 s
- после reconnect — сначала snapshot
- после трёх неудачных reconnect — foreground polling каждые 15 s
- после восстановления SSE polling останавливается

Errors

- `401 UNAUTHORIZED` / `401 TOKEN_INVALID` / `401 TERMINAL_INACTIVE`

---

# Production Status Ownership

- payment/order processing переводит валидный заказ в `CONFIRMED` и публикует его в kitchen channel
- только authenticated kitchen mutation начинает приготовление (`COOKING`) и завершает его (`READY`)
- автоматические timers (`SEND_TO_KITCHEN_JOB`, status timers) работают лишь при явном `KDS_STATUS_EMULATION_ENABLED=true` вне production; включение emulation в production — configuration error, останавливающий startup

---

# Validation Rules

- PIN ровно 4 цифры; `expectedVersion >= 1`
- переходы строго `CONFIRMED -> COOKING -> READY`, без пропусков и возвратов
- все действия журналируются в `OrderStatusHistory` (terminalId, cookId/shiftId, previous/new status, server timestamp)

---

# Error Codes

- `UNAUTHORIZED`
- `TOKEN_INVALID`
- `TERMINAL_INACTIVE`
- `TERMINAL_BRANCH_UNAVAILABLE`
- `ORDER_NOT_FOUND`
- `ORDER_BRANCH_FORBIDDEN`
- `ORDER_VERSION_CONFLICT`
- `INVALID_ORDER_STATUS_TRANSITION`
- `VALIDATION_ERROR`

---

# Security

- Bearer JWT (`KITCHEN`), TTL не дольше одной рабочей смены
- Активность терминала проверяется в БД на каждый запрос
- Branch Isolation: `403 ORDER_BRANCH_FORBIDDEN` на чужой филиал
- customer phone/address и payment details не входят в Kitchen DTO
- JWT, PIN и customer comments не попадают в logs/metrics
- Audit Logging

---

# Out Of Scope (Future)

Kitchen stations, production queue priorities, standalone timers и recipes зарезервированы под отдельные ADR (station-specific routing — см. Review Criteria ADR-1618) и не являются частью реализованного контракта.

---

# Related Documents

ADR-1618 Kitchen POS Architecture

DB-610 Kitchen & Production Schema

API-707 Order API

ADR-1617 Courier Mobile Architecture

ADR-1615 Realtime Order Timeline

END OF DOCUMENT
