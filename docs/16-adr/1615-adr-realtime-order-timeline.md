---
Document ID: ADR-1615

Document Name: ADR - REALTIME ORDER TIMELINE

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

# ADR - REALTIME ORDER TIMELINE

## Status

Accepted

## Context

Backend хранит канонический `OrderStatus`, а Customer Mobile требует стабильную клиентскую timeline-модель, realtime-доставку обновлений и детерминированный процент прогресса.

## Decision

Каждый успешно зафиксированный переход заказа ставит BullMQ job `order.timeline.publish`. Worker формирует версионированное событие и публикует его в Redis Pub/Sub. NestJS realtime gateway фильтрует доступ и отдаёт тот же event contract через SSE; WebSocket может быть добавлен как совместимый transport adapter.

```text
Order transaction -> BullMQ job -> BullMQ Worker -> Redis Pub/Sub
    -> WebSocket Gateway / SSE -> OrderTrackingBloc -> OrderStatusTracker
```

Redis Pub/Sub используется только для краткоживущего realtime fan-out и не заменяет RabbitMQ как межсервисный event bus по ADR-1603.

## Event Contract

```ts
type OrderTimelineStatus =
  | 'PENDING'
  | 'ACCEPTED'
  | 'COOKING'
  | 'COURIER_ASSIGNED'
  | 'ON_WAY'
  | 'DELIVERED';

type OrderTimelineEventV1 = {
  event_id: string;
  event_type: 'order.timeline.updated';
  event_version: 1;
  occurred_at: string;
  order_id: string;
  order_version: number;
  status: OrderTimelineStatus;
  progress_percent: 5 | 15 | 40 | 55 | 75 | 100;
  courier_id: string | null;
  estimated_delivery_at: string | null;
};
```

Redis channel: `order.timeline.{orderId}`. `event_id` передаётся как SSE `id`; heartbeat отправляется не реже одного раза в 20 секунд.

## Status Projection

| Client status | Backend source | Progress |
|---|---|---:|
| `PENDING` | `OrderStatus.NEW` | 5% |
| `ACCEPTED` | `OrderStatus.CONFIRMED` | 15% |
| `COOKING` | `OrderStatus.COOKING` | 40% |
| `COURIER_ASSIGNED` | `OrderStatus.READY` и `courierId != null` | 55% |
| `ON_WAY` | `OrderStatus.ON_WAY` | 75% |
| `DELIVERED` | `OrderStatus.COMPLETED` | 100% |

`READY` без `courierId` остаётся клиентской проекцией `COOKING` (40%) до назначения курьера. `CANCELLED` не входит в линейный progress: gateway отправляет отдельное terminal-событие `order.cancelled`, а UI показывает состояние отмены без процента.

## Transport Contract

- Snapshot: `GET /api/v1/orders/{orderId}/timeline`.
- SSE: `GET /api/v1/orders/{orderId}/timeline/stream`.
- Customer access token обязателен; пользователь может подписаться только на собственный заказ.
- Существующий branch-level courier SSE не переиспользуется напрямую в Customer Mobile и не раскрывается customer token.
- Gateway отправляет snapshot первым событием после подключения.

Redis Pub/Sub не хранит историю. При reconnect, неизвестном `Last-Event-ID` или пропуске `order_version` клиент повторно получает snapshot. `OrderTrackingBloc` игнорирует события с `order_version <= current.orderVersion`.

## Customer Mobile Contract

```dart
sealed class OrderTrackingEvent {}
final class OrderTrackingStarted extends OrderTrackingEvent { final String orderId; }
final class OrderTimelineReceived extends OrderTrackingEvent { final OrderTimelineDto timeline; }
final class OrderTrackingDisconnected extends OrderTrackingEvent {}
final class OrderTrackingRetried extends OrderTrackingEvent {}

class OrderTrackingState {
  final OrderTimelineStatus status;
  final int progressPercent;
  final int orderVersion;
  final bool isConnected;
  final DateTime? estimatedDeliveryAt;
}
```

Bloc загружает snapshot, открывает stream, применяет только возрастающие версии и использует exponential backoff с jitter. После foreground/resume всегда выполняется snapshot refresh.

## Delivery Guarantees

- Job создаётся после фиксации статуса; рекомендуемый production-механизм - transactional outbox, чтобы исключить разрыв между PostgreSQL и BullMQ.
- Worker допускает повторное выполнение; событие дедуплицируется по `event_id`, состояние - по `order_version`.
- Порядок гарантируется только внутри одного заказа.
- Realtime является ускорителем UI; PostgreSQL snapshot остаётся источником истины.

## Consequences

Положительные: единый контракт для SSE/WebSocket, изоляция backend enum, горизонтальное масштабирование gateway, восстановление после потери ephemeral-событий.

Отрицательные: Redis Pub/Sub не поддерживает replay; нужны snapshot endpoint, версия заказа, reconnect logic и outbox для строгой надёжности.

## Alternatives Rejected

- In-memory RxJS `Subject`: события теряются между экземплярами backend.
- Передавать backend enum напрямую: клиент становится зависимым от внутренних статусов.
- WebSocket-only: избыточен для однонаправленного Customer Mobile MVP.

## Review Criteria

Пересмотреть Redis Pub/Sub в пользу Redis Streams или RabbitMQ consumer, если потребуется replay, гарантированная доставка или длительная история realtime-событий.

## Related Documents

ADR-1603 Event-Driven Architecture

ADR-1605 NestJS as Backend Framework

ADR-1609 API-First and Contract-First Development

ADR-1614 Loyalty Service

ADR-1616 Customer User Settings

ARC-512 Background Jobs

END OF DOCUMENT
