---
Document ID: DB-610

Document Name: KITCHEN & PRODUCTION SCHEMA

Book: Database

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Database: PostgreSQL

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# KITCHEN & PRODUCTION SCHEMA

## Purpose

Определяет структуру данных Kitchen Display System и производственных процессов.

---

# Tables

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

# kitchen_orders

Columns

- id
- order_id
- station_id
- priority
- status
- started_at
- ready_at
- completed_at
- created_at
- updated_at

---

# kitchen_order_items

Columns

- id
- kitchen_order_id
- order_item_id
- status
- quantity
- started_at
- completed_at

---

# kitchen_stations

Columns

- id
- branch_id
- code
- name
- display_order
- is_active

Examples

- Sushi
- Hot Kitchen
- Pizza
- Drinks
- Desserts

---

# station_assignments

Columns

- id
- station_id
- employee_id
- started_at
- ended_at

---

# recipes

Columns

- id
- product_id
- version
- preparation_time
- yield_quantity
- is_active

---

# recipe_ingredients

Columns

- id
- recipe_id
- ingredient_id
- quantity
- unit

---

# preparation_steps

Columns

- id
- recipe_id
- step_number
- title
- description
- estimated_seconds

---

# kitchen_timers

Columns

- id
- kitchen_order_id
- started_at
- expected_finish_at
- finished_at

---

# production_queue

Columns

- id
- kitchen_order_id
- station_id
- queue_position
- priority

---

# kitchen_events

Columns

- id
- kitchen_order_id
- event_type
- employee_id
- payload
- created_at

---

# Relationships

orders

↓

kitchen_orders

↓

kitchen_order_items

↓

production_queue

↓

kitchen_events

---

products

↓

recipes

↓

recipe_ingredients

↓

ingredients

---

kitchen_stations

↓

station_assignments

↓

employees

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

# Business Rules

- Один заказ может иметь несколько кухонных заказов.
- Один кухонный заказ может обслуживаться одной станцией.
- Рецепт имеет версии.
- Каждый рецепт содержит минимум один ингредиент.
- Все изменения статуса фиксируются.
- Очередь пересчитывается автоматически.
- Приоритет влияет на порядок приготовления.
- Таймер запускается автоматически после начала приготовления.

---

# Performance

- Новый заказ отображается на кухне ≤ 3 секунд.
- Изменение статуса синхронизируется в реальном времени.
- Очередь поддерживает автоматическое обновление.

---

# Related Documents

DB-608 Order Schema

ARC-504 Event Driven Architecture

PB-305 Product Requirements

END OF DOCUMENT