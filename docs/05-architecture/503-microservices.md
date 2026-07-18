---
Document ID: ARC-503

Document Name: MICROSERVICES STRATEGY

Book: Architecture

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# MICROSERVICES STRATEGY

## Purpose

Определяет стратегию перехода SHIK Platform от модульного монолита к микросервисной архитектуре.

---

# Initial Architecture

Architecture Type

Modular Monolith

Reason

- Быстрая разработка MVP
- Простое развертывание
- Минимальная сложность
- Единая кодовая база
- Простая отладка

---

# Migration Strategy

Phase 1

Modular Monolith

↓

Phase 2

Extract Integration Module

↓

Phase 3

Extract Communication Module

↓

Phase 4

Extract Analytics Module

↓

Phase 5

Extract Delivery Module

↓

Phase 6

Full Microservices (при необходимости)

---

# Candidate Services

## Identity Service

Responsibilities

- Authentication
- Authorization
- Sessions
- Roles

---

## Customer Service

Responsibilities

- Profiles
- Addresses
- Favorites
- Loyalty

---

## Menu Service

Responsibilities

- Categories
- Products
- Prices
- Stop List

---

## Order Service

Responsibilities

- Cart
- Checkout
- Orders

---

## Payment Service

Responsibilities

- Payments
- Refunds
- Transactions

---

## Kitchen Service

Responsibilities

- Kitchen Display
- Recipes
- Timers
- Statuses

---

## Inventory Service

Responsibilities

- Ingredients
- Warehouses
- Stock

---

## Delivery Service

Responsibilities

- Couriers
- Delivery
- ETA

---

## Communication Service

Responsibilities

- Push
- WhatsApp Business
- Telegram
- Email
- SMS

---

## Analytics Service

Responsibilities

- Reports
- KPIs
- Dashboards

---

# Communication Between Services

Allowed

- REST API
- Domain Events
- Message Queue

Forbidden

- Direct Database Access
- Shared Business Logic

---

# Shared Infrastructure

- PostgreSQL
- Redis
- Object Storage
- Queue
- Monitoring
- Logging

---

# Design Principles

- Single Responsibility
- Loose Coupling
- High Cohesion
- Independent Deployment Ready
- API-First
- Event-Driven

---

# Exit Criteria

Переход к Microservices выполняется только если:

- более 100 000 активных пользователей;
- более 100 ресторанов;
- высокая нагрузка требует независимого масштабирования;
- появляются независимые команды разработки.

---

# Related Documents

ARC-501 System Overview

ARC-502 Modular Architecture

ARC-504 Event-Driven Architecture

END OF DOCUMENT