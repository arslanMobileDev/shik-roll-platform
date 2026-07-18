---
Document ID: API-707

Document Name: ORDER API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# ORDER API

## Purpose

Определяет REST API для корзины, оформления заказа, управления статусами и истории заказов.

---

# Base Endpoints

```text
/carts
/orders
```

---

# Cart Endpoints

## GET /carts/current

Purpose

Получить текущую корзину клиента.

Authentication

JWT

---

## POST /carts

Purpose

Создать корзину.

Authentication

JWT

Request

- branch_id
- order_type

---

## POST /carts/current/items

Purpose

Добавить товар в корзину.

Authentication

JWT

Request

- product_id
- quantity
- modifiers
- comment

---

## PATCH /carts/current/items/{itemId}

Purpose

Изменить позицию корзины.

Authentication

JWT

Request

- quantity
- modifiers
- comment

---

## DELETE /carts/current/items/{itemId}

Purpose

Удалить позицию из корзины.

Authentication

JWT

---

## DELETE /carts/current

Purpose

Очистить корзину.

Authentication

JWT

---

## POST /carts/current/apply-coupon

Purpose

Применить промокод.

Authentication

JWT

Request

- code

---

## DELETE /carts/current/coupon

Purpose

Удалить промокод.

Authentication

JWT

---

## POST /carts/current/calculate

Purpose

Пересчитать корзину.

Authentication

JWT

Response

- subtotal
- discount_total
- delivery_fee
- tax_total
- tip_total
- total
- estimated_ready_at

---

# Order Endpoints

## POST /orders

Purpose

Создать заказ из текущей корзины.

Authentication

JWT

Headers

- Idempotency-Key

Request

- branch_id
- order_type
- payment_method
- address_id
- pickup_time
- comment
- tip_amount
- loyalty_points

Response

- order
- payment_required
- payment

---

## GET /orders

Purpose

Получить историю заказов текущего клиента.

Authentication

JWT

Supports

- Pagination
- Status Filter
- Date Range

---

## GET /orders/{id}

Purpose

Получить заказ.

Authentication

JWT

---

## GET /orders/{id}/status-history

Purpose

Получить историю статусов заказа.

Authentication

JWT

---

## POST /orders/{id}/cancel

Purpose

Отменить заказ.

Authentication

JWT

Request

- reason

---

## POST /orders/{id}/repeat

Purpose

Повторить заказ.

Authentication

JWT

Response

- cart

---

# Internal Order Management

## GET /admin/orders

Purpose

Получить список заказов для Back Office, POS и кухни.

Authentication

JWT

Permission

order.view

Supports

- Branch
- Status
- Order Type
- Payment Status
- Date Range
- Customer
- Order Number
- Pagination
- Sorting

---

## GET /admin/orders/{id}

Purpose

Получить полную информацию о заказе.

Permission

order.view

---

## PATCH /admin/orders/{id}

Purpose

Изменить разрешенные данные заказа.

Permission

order.update

Request

- comment
- estimated_ready_at
- assigned_courier_id

---

## POST /admin/orders/{id}/confirm

Purpose

Подтвердить заказ.

Permission

order.confirm

---

## POST /admin/orders/{id}/status

Purpose

Изменить статус заказа.

Permission

order.update_status

Request

- status
- reason

---

## POST /admin/orders/{id}/cancel

Purpose

Отменить заказ сотрудником.

Permission

order.cancel

Request

- reason

---

## POST /admin/orders/{id}/refund

Purpose

Инициировать возврат.

Permission

payment.refund

Request

- amount
- reason

---

# Supported Order Types

- Delivery
- Pickup
- Dine In

---

# Supported Order Statuses

- Draft
- Created
- Confirmed
- Preparing
- Ready
- Courier Assigned
- On Delivery
- Ready For Pickup
- Completed
- Cancelled
- Refunded

---

# Validation Rules

- корзина не должна быть пустой;
- все товары должны быть доступны в выбранном филиале;
- цена пересчитывается на сервере;
- клиент не может изменить заказ после подтверждения, если это запрещено правилами;
- адрес обязателен для доставки;
- филиал обязателен;
- Idempotency-Key обязателен при создании заказа;
- заказ нельзя завершить без успешной оплаты, если не выбрана оплата при получении.

---

# Events

- OrderCreated
- OrderConfirmed
- OrderPreparing
- OrderReady
- CourierAssigned
- OrderOutForDelivery
- OrderCompleted
- OrderCancelled
- OrderRefunded

---

# Error Codes

- CART_NOT_FOUND
- CART_EMPTY
- CART_ITEM_NOT_FOUND
- PRODUCT_UNAVAILABLE
- INVALID_MODIFIER
- COUPON_INVALID
- COUPON_EXPIRED
- BRANCH_CLOSED
- DELIVERY_ADDRESS_REQUIRED
- DELIVERY_ZONE_NOT_SUPPORTED
- ORDER_NOT_FOUND
- ORDER_CANNOT_BE_CANCELLED
- INVALID_ORDER_STATUS_TRANSITION
- PAYMENT_REQUIRED
- DUPLICATE_ORDER_REQUEST
- ACCESS_DENIED
- VALIDATION_ERROR

---

# Security

- JWT Required
- RBAC
- Branch Isolation
- Idempotency
- Audit Logging
- Rate Limiting

---

# Related Documents

DB-608 Order Schema

API-706 Menu & Product API

API-708 Payment API

ARC-504 Event-Driven Architecture

PB-305 Product Requirements

END OF DOCUMENT