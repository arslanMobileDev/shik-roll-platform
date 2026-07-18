---
Document ID: API-711

Document Name: INVENTORY API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# INVENTORY API

## Purpose

Определяет REST API для управления ингредиентами, складами и остатками.

---

# Base Endpoint

```text
/inventory
```

---

# Ingredients

## GET /inventory/ingredients

Purpose

Получить список ингредиентов.

Supports

- Search
- Pagination
- Category
- Status

---

## GET /inventory/ingredients/{id}

Purpose

Получить ингредиент.

---

## POST /inventory/ingredients

Purpose

Создать ингредиент.

Permission

inventory.create

---

## PATCH /inventory/ingredients/{id}

Purpose

Изменить ингредиент.

Permission

inventory.update

---

## DELETE /inventory/ingredients/{id}

Purpose

Архивировать ингредиент.

Permission

inventory.delete

---

# Warehouses

## GET /inventory/warehouses

Purpose

Получить склады.

---

## POST /inventory/warehouses

Purpose

Создать склад.

---

## PATCH /inventory/warehouses/{id}

Purpose

Изменить склад.

---

## DELETE /inventory/warehouses/{id}

Purpose

Архивировать склад.

---

# Stock

## GET /inventory/stock

Purpose

Получить остатки.

Supports

- Warehouse
- Ingredient
- Low Stock

---

## POST /inventory/stock/adjustment

Purpose

Корректировка остатков.

Permission

inventory.adjust

Request

- warehouse_id
- ingredient_id
- quantity
- reason

---

## POST /inventory/stock/transfer

Purpose

Перемещение между складами.

Permission

inventory.transfer

Request

- source_warehouse_id
- destination_warehouse_id
- items

---

# Inventory Count

## POST /inventory/count/start

Purpose

Начать инвентаризацию.

---

## POST /inventory/count/{id}/complete

Purpose

Завершить инвентаризацию.

---

# Stock Movements

## GET /inventory/movements

Purpose

Получить журнал движений.

Supports

- Date
- Warehouse
- Ingredient
- Movement Type

---

# Suppliers

## GET /inventory/suppliers

---

## POST /inventory/suppliers

---

## PATCH /inventory/suppliers/{id}

---

## DELETE /inventory/suppliers/{id}

---

# Purchase Orders

## GET /inventory/purchase-orders

---

## POST /inventory/purchase-orders

---

## PATCH /inventory/purchase-orders/{id}

---

## POST /inventory/purchase-orders/{id}/receive

Purpose

Принять поставку.

---

# Stop List

## POST /inventory/stop-list/update

Purpose

Пересчитать Stop List по остаткам.

Permission

inventory.manage

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

# Validation Rules

- Отрицательные остатки запрещены.
- Все движения выполняются в транзакции.
- Все изменения журналируются.
- Stop List обновляется автоматически.
- Инвентаризация блокирует параллельные корректировки.

---

# Events

- InventoryUpdated
- StockLow
- StockOut
- StockAdjusted
- StockTransferred
- InventoryCountCompleted
- StopListUpdated

---

# Error Codes

- INGREDIENT_NOT_FOUND
- WAREHOUSE_NOT_FOUND
- INSUFFICIENT_STOCK
- INVALID_QUANTITY
- INVENTORY_COUNT_ACTIVE
- SUPPLIER_NOT_FOUND
- PURCHASE_ORDER_NOT_FOUND
- ACCESS_DENIED

---

# Security

- JWT Required
- RBAC
- Branch Isolation
- Audit Logging

---

# Related Documents

DB-611 Inventory & Warehouse Schema

API-709 Kitchen API

ARC-504 Event-Driven Architecture

PB-305 Product Requirements

END OF DOCUMENT