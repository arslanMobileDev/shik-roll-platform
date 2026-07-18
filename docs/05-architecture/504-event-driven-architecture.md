---
Document ID: ARC-504

Document Name: EVENT DRIVEN ARCHITECTURE

Book: Architecture

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Architecture Style: Event Driven

Last Updated: July 2026

Classification: Internal
---

# EVENT DRIVEN ARCHITECTURE

## Purpose

Определяет правила взаимодействия модулей SHIK Platform через доменные события.

---

# Principles

- Business First
- Loose Coupling
- Event Driven
- Asynchronous Processing
- Idempotency
- Auditability
- Event Replay Ready

---

# Event Lifecycle

Business Action

↓

Domain Event

↓

Event Bus

↓

Subscribers

↓

Business Processing

↓

Audit Log

---

# Event Categories

## Customer Events

- CustomerRegistered
- CustomerUpdated
- CustomerDeleted
- CustomerLoggedIn

---

## Menu Events

- MenuPublished
- ProductCreated
- ProductUpdated
- ProductDeleted
- StopListUpdated

---

## Order Events

- OrderCreated
- OrderConfirmed
- OrderPreparing
- OrderReady
- OrderCompleted
- OrderCancelled
- OrderRefunded

---

## Payment Events

- PaymentCreated
- PaymentSucceeded
- PaymentFailed
- RefundCompleted

---

## Kitchen Events

- KitchenOrderAccepted
- KitchenStartedCooking
- KitchenOrderReady
- KitchenDelayDetected

---

## Delivery Events

- CourierAssigned
- CourierStarted
- CourierArrived
- OrderDelivered

---

## Inventory Events

- InventoryUpdated
- StockLow
- StockOut
- InventoryAdjusted

---

## Communication Events

- NotificationQueued
- NotificationSent
- NotificationDelivered
- NotificationFailed

---

## Employee Events

- EmployeeCreated
- EmployeeUpdated
- ShiftOpened
- ShiftClosed

---

## Security Events

- LoginSucceeded
- LoginFailed
- PermissionChanged
- TwoFactorEnabled

---

# Event Rules

- Каждое событие имеет уникальный Event ID.
- События являются неизменяемыми.
- События содержат UTC-время создания.
- События содержат Correlation ID.
- События содержат Producer.
- Повторная обработка не должна менять результат (идемпотентность).
- Все события записываются в Audit Log.

---

# Event Structure

Each Event Contains

- Event ID
- Event Type
- Version
- Timestamp (UTC)
- Correlation ID
- Aggregate ID
- Producer
- Payload
- Metadata

---

# Subscribers

Possible Subscribers

- Customer Module
- Order Module
- Kitchen Module
- Payment Module
- Delivery Module
- Communication Automation Center
- Analytics
- Audit
- Integration Layer

---

# Communication Automation Center Integration

Communication Automation Center подписывается на события:

- OrderCreated
- OrderConfirmed
- OrderReady
- OrderCompleted
- PaymentFailed
- LoyaltyPointsAdded

После получения события модуль самостоятельно определяет:

- шаблон;
- канал;
- получателя;
- язык;
- филиал;
- расписание;
- резервный канал.

---

# Error Handling

Если обработка события завершилась ошибкой:

- событие повторяется;
- превышение лимита попыток отправляет событие в Dead Letter Queue;
- ошибка журналируется;
- администратор получает уведомление (если событие критическое).

---

# Design Principles

- No Shared Database
- No Direct Module Calls
- API for Commands
- Events for Notifications
- Independent Subscribers
- Replay Support
- Horizontal Scalability

---

# Future Improvements

Phase 2

- Kafka
- RabbitMQ
- Event Store
- Event Replay
- CQRS
- Saga Pattern

---

# Related Documents

ARC-501 System Overview

ARC-502 Modular Architecture

ARC-503 Microservices Strategy

ARC-505 Domain Model

PB-305 Product Requirements

END OF DOCUMENT