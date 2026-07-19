---
Document ID: ARC-512

Document Name: BACKGROUND JOBS

Book: Architecture

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# BACKGROUND JOBS

## Purpose

Определяет архитектуру фоновых задач SHIK Platform.

---

# Principles

- Asynchronous Processing
- Retry Support
- Idempotency
- Monitoring
- Horizontal Scaling

---

# Queue Technologies

## Background Jobs (MVP)

- BullMQ
- Redis

Используются для локальных фоновых заданий, повторных попыток и плановых задач.

## Event Bus

- RabbitMQ

Используется для межмодульных, межсервисных и интеграционных событий.

## Future

- Kafka

---

# Job Categories

## Communication

- Send Push
- Send Email
- Send WhatsApp
- Send Telegram
- Send SMS

---

## Orders

- Auto Cancel Unpaid Orders
- Update Delivery Status
- Complete Orders

---

## Inventory

- Low Stock Check
- Stop List Update
- Daily Inventory Sync

---

## Catalog

- Catalog Import Validation
- Catalog Import Upsert
- Published Menu Cache Warmup
- Product Search Index Update

Rules

- Импорт должен быть идемпотентным по стабильному `source_key`.
- Ошибки отдельных строк сохраняются в задании импорта и не теряются при повторной обработке.
- Прогрев публичного кеша запускается только после успешной публикации версии меню.

---

## Analytics

- KPI Calculation
- Sales Aggregation
- Dashboard Refresh

---

## Maintenance

- Cleanup Logs
- Cleanup Sessions
- Cleanup Files
- Cleanup Cache

---

## Reports

- Daily Report
- Weekly Report
- Monthly Report

---

## Loyalty

- Add Bonus Points
- Expire Bonus Points
- Birthday Rewards

---

## Media

- Image Optimization
- Thumbnail Generation
- Deleted Image Cleanup

Rules

- Очистка выполняется только для изображения, помеченного удаленным в PostgreSQL.
- Повторный запуск очистки не должен приводить к ошибке или удалению активного объекта.

---

# Retry Policy

Attempt 1

↓

Retry after 30 sec

↓

Retry after 2 min

↓

Retry after 10 min

↓

Dead Letter Queue

---

# Monitoring

- Queue Size
- Failed Jobs
- Processing Time
- Retry Count
- Dead Letter Queue

---

# Rules

- Jobs must be idempotent.
- Long-running operations must execute in background.
- Failed jobs must be logged.
- Critical failures must notify administrators.

---

# Performance

Queue Delay

- ≤5 seconds

Job Timeout

- Configurable

Concurrent Workers

- Auto Scaling Ready

---

# Related Documents

ARC-504 Event-Driven Architecture

ARC-507 Deployment Architecture

ARC-509 Caching Strategy

ARC-513 Communication Architecture

END OF DOCUMENT
