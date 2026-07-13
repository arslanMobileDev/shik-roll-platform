---
Document ID: BE-911

Document Name: INVENTORY SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# INVENTORY SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Inventory Service.

---

# Responsibilities

- Warehouse Management
- Ingredient Management
- Stock Management
- Stock Movements
- Purchase Orders
- Supplier Management
- Inventory Count
- Automatic Stop List
- Stock Forecasting

---

# Public API

- Ingredients
- Warehouses
- Stock
- Stock Movements
- Purchase Orders
- Suppliers
- Inventory Count
- Stop List

---

# Dependencies

- Menu Service
- Kitchen Service
- Order Service
- Analytics Service
- Audit Service

---

# Database

Tables

- warehouses
- ingredients
- stock
- stock_movements
- purchase_orders
- purchase_order_items
- suppliers
- inventory_counts
- inventory_count_items
- stock_reservations
- stop_list_rules

---

# Events Published

- IngredientCreated
- StockUpdated
- StockReserved
- StockReleased
- LowStockDetected
- OutOfStockDetected
- PurchaseOrderCreated
- InventoryCountCompleted
- StopListUpdated

---

# Events Consumed

- OrderConfirmed
- OrderCancelled
- KitchenOrderStarted
- KitchenOrderCompleted
- ProductRecipeUpdated

---

# Business Rules

- Остатки не могут быть отрицательными.
- Все движения выполняются транзакционно.
- Поддерживается резервирование ингредиентов.
- После приготовления резерв списывается.
- Stop List обновляется автоматически.
- Минимальные остатки настраиваются отдельно для каждого филиала.
- Все изменения журналируются.
- Все события публикуются через Event Bus.

---

# Transactions

Atomic Operations

- Reserve Stock
- Release Stock
- Consume Stock
- Stock Adjustment
- Warehouse Transfer

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

- Low Stock Monitoring
- Stop List Synchronization
- Inventory Forecast
- Purchase Recommendation
- Stock Reconciliation

---

# Error Codes

- INGREDIENT_NOT_FOUND
- WAREHOUSE_NOT_FOUND
- STOCK_NOT_FOUND
- INSUFFICIENT_STOCK
- PURCHASE_ORDER_NOT_FOUND
- INVENTORY_COUNT_ACTIVE
- SUPPLIER_NOT_FOUND
- ACCESS_DENIED

---

# Performance

- Stock Lookup ≤ 100 ms
- Stock Reservation ≤ 150 ms
- Stop List Update ≤ 5 sec
- Inventory Report ≤ 3 sec

---

# Related Documents

API-711 Inventory API

DB-611 Inventory & Warehouse Schema

BE-909 Kitchen Service

BE-906 Menu & Product Service

ARC-504 Event Driven Architecture

END OF DOCUMENT