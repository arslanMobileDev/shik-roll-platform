---
Document ID: ARC-509

Document Name: CACHING STRATEGY

Book: Architecture

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# CACHING STRATEGY

## Purpose

Определяет стратегию кеширования SHIK Platform.

---

# Cache Technology

Primary Cache

- Redis

---

# Goals

- Reduce Database Load
- Improve Response Time
- Support High Traffic
- Increase Scalability

---

# Cached Data

## Menu

- Published Catalog Version
- Categories
- Products
- Prices
- Modifiers
- Stop List

TTL

- 10 minutes

---

## Restaurant

- Branches
- Working Hours
- Delivery Zones

TTL

- 30 minutes

---

## Configuration

- System Settings
- Feature Flags
- Communication Rules

TTL

- 60 minutes

---

## Customer

- Session
- Profile

TTL

- Session Lifetime

---

## Analytics

- Dashboard Widgets
- KPI

TTL

- 5 minutes

---

# Cache Invalidation

Triggered By

- Product Updated
- Menu Published
- Menu Unpublished
- Product Status Changed
- Product Media Changed
- Price Changed
- Stop List Updated
- Branch Updated
- Configuration Changed

---

# Cache Policy

Read

Cache First

Write

Database First

Invalidate Cache

Refresh Cache

---

# Catalog Cache Boundaries

- Публичный кеш содержит только Published-версию каталога.
- Draft и Preview не записываются в публичный клиентский кеш.
- Завершение импорта обновляет Draft и само по себе не изменяет опубликованный кеш.
- Publish атомарно переключает активную версию и инициирует прогрев кеша.
- Unpublish удаляет публичную версию из кеша.
- Изменения статуса, цены, медиа, доступности и Stop List инвалидируют только затронутые ключи опубликованного каталога.

---

# Do Not Cache

- Payments
- Passwords
- Tokens
- Audit Log
- Permissions
- Financial Transactions

---

# Redis Usage

- Cache
- Sessions
- Rate Limiting
- Queue Storage
- OTP Codes

---

# Performance Targets

Cache Hit Rate

- ≥90%

Average Cache Response

- <10 ms

---

# Monitoring

- Cache Hit Rate
- Cache Miss Rate
- Memory Usage
- Evictions
- Latency

---

# Related Documents

ARC-507 Deployment Architecture

ARC-508 Technology Stack

ARC-510 File Storage

END OF DOCUMENT
