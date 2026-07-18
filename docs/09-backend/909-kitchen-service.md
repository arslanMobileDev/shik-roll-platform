---
Document ID: BE-909

Document Name: KITCHEN SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# KITCHEN SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Kitchen Service.

---

# Responsibilities

- Kitchen Order Management
- Production Queue
- Kitchen Stations
- Recipe Management
- Preparation Timers
- Kitchen Events
- Production Monitoring

---

# Public API

- Kitchen Orders
- Stations
- Production Queue
- Recipes
- Timers
- Kitchen Events

---

# Dependencies

- Order Service
- Menu Service
- Inventory Service
- Employee Service
- Communication Service
- Audit Service

---

# Database

Tables

- kitchen_orders
- kitchen_order_items
- kitchen_stations
- station_assignments
- recipes
- recipe_ingredients
- preparation_steps
- kitchen_timers
- production_queue
- kitchen_events

---

# Events Published

- KitchenOrderAccepted
- KitchenPreparationStarted
- KitchenOrderReady
- KitchenOrderCompleted
- KitchenOrderCancelled
- KitchenDelayDetected

---

# Events Consumed

- OrderConfirmed
- OrderCancelled
- InventoryUpdated
- EmployeeAssigned

---

# Kitchen Workflow

- Waiting
- Accepted
- Preparing
- Ready
- Completed
- Cancelled

---

# Business Rules

- Один кухонный заказ относится к одному заказу.
- Один заказ может быть распределен между несколькими станциями.
- Очередь автоматически пересчитывается.
- Приоритет влияет на порядок приготовления.
- Таймер запускается автоматически после начала приготовления.
- Рецепт определяет ожидаемое время приготовления.
- Все действия сотрудников журналируются.
- Все изменения публикуются через Event Bus.

---

# Transactions

Atomic Operations

- Accept Order
- Start Cooking
- Complete Cooking
- Cancel Kitchen Order

Rollback

Required On Failure

---

# Security

- JWT
- RBAC
- Branch Isolation
- Audit Logging

---

# Background Jobs

- Queue Recalculation
- Timer Monitoring
- Delay Detection
- Kitchen Statistics Update

---

# Error Codes

- KITCHEN_ORDER_NOT_FOUND
- STATION_NOT_FOUND
- RECIPE_NOT_FOUND
- INVALID_STATUS
- TIMER_ALREADY_RUNNING
- ACCESS_DENIED

---

# Performance

- Queue Update ≤ 100 ms
- Status Update ≤ 100 ms
- New Kitchen Order ≤ 2 sec
- Timer Update Real-Time

---

# Related Documents

API-709 Kitchen API

DB-610 Kitchen & Production Schema

BE-907 Order Service

ARC-504 Event-Driven Architecture

END OF DOCUMENT