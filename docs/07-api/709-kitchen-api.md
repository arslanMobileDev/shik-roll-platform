---
Document ID: API-709

Document Name: KITCHEN API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# KITCHEN API

## Purpose

Определяет REST API Kitchen Display System и управления производством.

---

# Base Endpoint

```text
/kitchen
```

---

# Kitchen Orders

## GET /kitchen/orders

Purpose

Получить очередь кухни.

Authentication

JWT

Permission

kitchen.view

Supports

- Branch
- Station
- Status
- Priority

---

## GET /kitchen/orders/{id}

Purpose

Получить кухонный заказ.

Authentication

JWT

---

## POST /kitchen/orders/{id}/accept

Purpose

Принять заказ в работу.

Permission

kitchen.accept

---

## POST /kitchen/orders/{id}/start

Purpose

Начать приготовление.

Permission

kitchen.start

---

## POST /kitchen/orders/{id}/ready

Purpose

Отметить как готовый.

Permission

kitchen.ready

---

## POST /kitchen/orders/{id}/complete

Purpose

Завершить приготовление.

Permission

kitchen.complete

---

## POST /kitchen/orders/{id}/cancel

Purpose

Отменить приготовление.

Permission

kitchen.cancel

Request

- reason

---

# Kitchen Stations

## GET /kitchen/stations

Purpose

Получить станции кухни.

---

## POST /kitchen/stations

Purpose

Создать станцию.

Permission

kitchen.station.create

---

## PATCH /kitchen/stations/{id}

Purpose

Изменить станцию.

Permission

kitchen.station.update

---

## DELETE /kitchen/stations/{id}

Purpose

Архивировать станцию.

Permission

kitchen.station.delete

---

# Production Queue

## GET /kitchen/queue

Purpose

Получить производственную очередь.

---

## PATCH /kitchen/queue/{id}/priority

Purpose

Изменить приоритет.

Permission

kitchen.queue.manage

Request

- priority

---

# Timers

## GET /kitchen/timers

Purpose

Получить активные таймеры.

---

## POST /kitchen/timers/{id}/start

Purpose

Запустить таймер.

---

## POST /kitchen/timers/{id}/stop

Purpose

Остановить таймер.

---

# Recipes

## GET /kitchen/recipes/{productId}

Purpose

Получить рецепт.

Permission

recipe.view

---

# Kitchen Events

## GET /kitchen/events

Purpose

Получить события кухни.

Permission

kitchen.view

---

# Kitchen Status

- Waiting
- Accepted
- Preparing
- Ready
- Completed
- Cancelled

---

# Priority

- Low
- Normal
- High
- Urgent

---

# Validation Rules

- Заказ принимается только один раз.
- Статусы изменяются последовательно.
- Таймер запускается после начала приготовления.
- Только назначенная станция изменяет свой заказ.
- Все действия журналируются.

---

# Events

- KitchenOrderAccepted
- KitchenStartedCooking
- KitchenOrderReady
- KitchenOrderCompleted
- KitchenDelayDetected

---

# Error Codes

- KITCHEN_ORDER_NOT_FOUND
- STATION_NOT_FOUND
- INVALID_STATUS
- INVALID_PRIORITY
- TIMER_ALREADY_RUNNING
- RECIPE_NOT_FOUND
- ACCESS_DENIED

---

# Security

- JWT Required
- RBAC
- Branch Isolation
- Audit Logging

---

# Related Documents

DB-610 Kitchen & Production Schema

API-707 Order API

ARC-504 Event Driven Architecture

PB-305 Product Requirements

END OF DOCUMENT