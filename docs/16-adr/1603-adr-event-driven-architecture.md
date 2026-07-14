---
Document ID: ADR-1603

Document Name: ADR — EVENT-DRIVEN ARCHITECTURE

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: July 2026

Classification: Internal
---

# ADR — EVENT-DRIVEN ARCHITECTURE

## Status

Accepted

---

# Context

SHIK Platform состоит из большого количества независимых сервисов:

- Authentication
- Customer
- Order
- Payment
- Kitchen
- Delivery
- Inventory
- Loyalty
- Communication
- Analytics

Сервисы постоянно обмениваются событиями.

---

# Problem

Необходимо выбрать способ взаимодействия между сервисами.

Основные варианты:

- Synchronous REST
- Event-Driven Messaging
- gRPC
- Hybrid Architecture

Требования:

- высокая масштабируемость;
- слабая связанность;
- устойчивость к отказам;
- асинхронная обработка;
- возможность горизонтального масштабирования.

---

# Decision

Использовать **Event-Driven Architecture** с **RabbitMQ** как основной механизм взаимодействия между сервисами.

REST API использовать только для синхронных пользовательских запросов.

---

# Rationale

Event-Driven Architecture обеспечивает:

- слабую связанность сервисов;
- независимое масштабирование;
- асинхронную обработку;
- устойчивость к временной недоступности сервисов;
- простое добавление новых подписчиков;
- удобную интеграцию с аналитикой и AI.

---

# Alternatives Considered

## REST Only

Advantages

- Простота
- Хорошая читаемость

Disadvantages

- Высокая связанность
- Каскадные сбои
- Сложное масштабирование
- Повышенные задержки

---

## gRPC

Advantages

- Высокая производительность
- Строгие контракты

Disadvantages

- Менее удобно для событийной модели
- Более сложная интеграция
- Более высокий порог входа

---

## Apache Kafka

Advantages

- Очень высокая производительность
- Отличная масштабируемость

Disadvantages

- Избыточная сложность для текущего масштаба
- Более дорогое сопровождение
- Более сложная эксплуатация

---

# Consequences

Positive

- Loose Coupling
- Independent Services
- Easy Scalability
- Reliable Messaging
- Retry Support
- Dead Letter Queue
- Event Replay Ready

Negative

- Eventual Consistency
- Более сложная отладка
- Необходимость мониторинга очередей
- Более сложная трассировка запросов

---

# Risks

- Потеря сообщений
- Дублирование событий
- Нарушение порядка обработки
- Переполнение очередей

Mitigation

- Durable Queues
- Publisher Confirms
- Consumer Acknowledgements
- Idempotent Consumers
- Dead Letter Queue
- Retry Policy
- Correlation ID
- Distributed Tracing

---

# Event Principles

- Immutable Events
- One Business Event = One Message
- Versioned Events
- Event Schema Validation
- At-Least-Once Delivery
- Idempotent Processing

---

# Messaging Standards

Broker

- RabbitMQ

Exchange Type

- Topic

Delivery

- Persistent Messages

Retry

- Exponential Backoff

Failed Messages

- Dead Letter Queue

---

# Success Criteria

- Независимое масштабирование сервисов
- Отсутствие каскадных отказов
- Надежная доставка сообщений
- Высокая производительность обработки событий
- Простое подключение новых сервисов

---

# Review Criteria

Пересмотр решения возможен при:

- росте нагрузки более чем в 10 раз;
- необходимости потоковой аналитики в реальном времени;
- переходе на распределенную мульти-региональную архитектуру.

---

# Related Documents

ARC-504 Event Driven Architecture

BE-901 Backend Overview

DEV-1205 Docker & Containerization

INT-1007 Integration Security & Monitoring

END OF DOCUMENT