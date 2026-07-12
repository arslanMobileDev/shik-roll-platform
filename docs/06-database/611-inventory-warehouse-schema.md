---
Document ID: DB-611

Document Name: INVENTORY & WAREHOUSE SCHEMA

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

# INVENTORY & WAREHOUSE SCHEMA

## Purpose

Определяет структуру складского учета, ингредиентов и движения запасов.

---

# Tables

- ingredients
- ingredient_categories
- units
- warehouses
- warehouse_locations
- inventory
- stock_movements
- stock_adjustments
- stock_transfers
- inventory_counts
- suppliers

---

# ingredients

Columns

- id
- sku
- name
- category_id
- unit_id
- minimum_stock
- reorder_level
- shelf_life_days
- is_active
- created_at
- updated_at

---

# ingredient_categories

Columns

- id
- name
- description

---

# units

Columns

- id
- code
- name

Examples

- pcs
- g
- kg
- ml
- l

---

# warehouses

Columns

- id
- branch_id
- name
- code
- is_active

---

# warehouse_locations

Columns

- id
- warehouse_id
- name
- code

---

# inventory

Columns

- id
- warehouse_id
- ingredient_id
- quantity
- reserved_quantity
- available_quantity
- updated_at

---

# stock_movements

Columns

- id
- warehouse_id
- ingredient_id
- movement_type
- quantity
- reference_type
- reference_id
- employee_id
- created_at

---

# stock_adjustments

Columns

- id
- warehouse_id
- ingredient_id
- previous_quantity
- new_quantity
- reason
- employee_id
- created_at

---

# stock_transfers

Columns

- id
- source_warehouse_id
- destination_warehouse_id
- status
- transferred_at

---

# inventory_counts

Columns

- id
- warehouse_id
- started_at
- completed_at
- employee_id
- status

---

# suppliers

Columns

- id
- name
- contact_name
- phone
- email
- status

---

# Relationships

warehouses

↓

inventory

↓

ingredients

↓

stock_movements

↓

stock_adjustments

---

ingredients

↓

recipes

↓

products

---

# Movement Types

- Purchase
- Production
- Sale
- Transfer
- Adjustment
- Waste
- Inventory Count

---

# Business Rules

- Остатки ведутся отдельно по каждому складу.
- Отрицательный остаток запрещен (если не разрешен настройками).
- Все движения запасов фиксируются.
- Списание требует указания причины.
- При достижении минимального остатка создается событие.
- Недостаток ингредиентов может автоматически перевести блюда в Stop List.

---

# Performance

- Обновление остатков в реальном времени.
- Поддержка пакетных операций.
- Идемпотентность всех движений.

---

# Related Documents

DB-607 Menu & Product Schema

DB-610 Kitchen & Production Schema

ARC-504 Event Driven Architecture

PB-305 Product Requirements

END OF DOCUMENT