---
Document ID: BE-907

Document Name: ORDER SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# ORDER SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Order Service.

---

# Responsibilities

- Cart Management
- Order Management
- Order Validation
- Order Status Management
- Discounts
- Coupons
- Tips
- Order History
- Order Tracking

---

# Public API

- Carts
- Orders
- Order Status
- Order History
- Repeat Order
- Cancel Order

---

# Dependencies

- Customer Service
- Menu Service
- Payment Service
- Kitchen Service
- Delivery Service
- Loyalty Service
- Communication Service
- Inventory Service
- Audit Service

---

# Database

Tables

- carts
- cart_items
- orders
- order_items
- order_status_history
- order_discounts
- order_coupons
- order_tips
- order_events
- order_audit

---

# Events Published

- CartCreated
- CartUpdated
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

# Events Consumed

- PaymentSucceeded
- PaymentFailed
- KitchenOrderReady
- CourierAssigned
- DeliveryCompleted
- LoyaltyPointsRedeemed
- InventoryUpdated

---

# Order Lifecycle

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

# Business Rules

- Один заказ создается из одной корзины.
- Корзина может быть оформлена только один раз.
- Цена всегда пересчитывается на сервере.
- Все скидки рассчитываются до оплаты.
- Все изменения статуса проходят проверку допустимых переходов.
- Каждое изменение статуса сохраняется в истории.
- Каждое действие записывается в Audit.
- Все события публикуются через Event Bus.
- После подтверждения заказа изменение состава запрещено, если это не разрешено бизнес-правилами.
- Заказ является источником данных для Analytics.

---

# Transactions

Atomic Operations

- Create Order
- Confirm Order
- Cancel Order
- Refund Order

Rollback

Required On Any Failure

---

# Security

- JWT
- RBAC
- Idempotency
- Audit Logging
- Input Validation

---

# Background Jobs

- Expired Cart Cleanup
- Order Status Synchronization
- Order Analytics Update
- Customer Statistics Update

---

# Error Codes

- CART_NOT_FOUND
- CART_EMPTY
- ORDER_NOT_FOUND
- PRODUCT_UNAVAILABLE
- INVALID_ORDER_STATUS
- ORDER_ALREADY_COMPLETED
- ORDER_ALREADY_CANCELLED
- PAYMENT_REQUIRED
- ACCESS_DENIED

---

# Performance

- Cart Update ≤ 100 ms
- Order Creation ≤ 500 ms
- Order Status Update ≤ 200 ms
- Order Search ≤ 150 ms

---

# Related Documents

API-707 Order API

DB-608 Order Schema

BE-906 Menu & Product Service

BE-908 Payment Service

ARC-504 Event Driven Architecture

END OF DOCUMENT