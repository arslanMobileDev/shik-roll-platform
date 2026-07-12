---
Document ID: DB-608

Document Name: ORDER SCHEMA

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

# ORDER SCHEMA

## Purpose

Определяет структуру хранения корзины, заказов и полного жизненного цикла заказа.

---

# Tables

- carts
- cart_items
- orders
- order_items
- order_status_history
- order_discounts
- order_coupons
- order_taxes
- order_tips
- order_events
- order_audit

---

# carts

Columns

- id
- customer_id
- branch_id
- status
- subtotal
- discount_total
- delivery_fee
- tax_total
- total
- expires_at
- created_at
- updated_at

---

# cart_items

Columns

- id
- cart_id
- product_id
- quantity
- unit_price
- total_price
- comment
- created_at

---

# orders

Columns

- id
- order_number
- customer_id
- branch_id
- cart_id
- order_type
- payment_status
- order_status
- subtotal
- discount_total
- delivery_fee
- tax_total
- tip_total
- total
- currency
- estimated_ready_at
- completed_at
- cancelled_at
- created_at
- updated_at

Indexes

- order_number
- customer_id
- branch_id
- order_status
- payment_status

---

# order_items

Columns

- id
- order_id
- product_id
- quantity
- unit_price
- total_price
- comment

---

# order_status_history

Columns

- id
- order_id
- previous_status
- new_status
- changed_by
- changed_at

---

# order_discounts

Columns

- id
- order_id
- promotion_id
- discount_type
- discount_value

---

# order_coupons

Columns

- id
- order_id
- coupon_id
- code
- discount_amount

---

# order_taxes

Columns

- id
- order_id
- tax_name
- tax_rate
- tax_amount

---

# order_tips

Columns

- id
- order_id
- amount
- payment_method

---

# order_events

Columns

- id
- order_id
- event_type
- payload
- created_at

---

# order_audit

Columns

- id
- order_id
- user_id
- action
- old_value
- new_value
- created_at

---

# Relationships

customers

↓

carts

↓

cart_items

↓

orders

↓

order_items

↓

payments

↓

delivery

↓

analytics

---

orders

↓

order_status_history

↓

order_events

↓

order_audit

---

# Order Statuses

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

# Order Types

- Delivery
- Pickup
- Dine In

---

# Payment Status

- Pending
- Paid
- Failed
- Refunded

---

# Business Rules

- Номер заказа уникален.
- Корзина может быть преобразована только в один заказ.
- Заказ не удаляется физически.
- Каждое изменение статуса записывается в историю.
- Каждое действие записывается в Audit.
- Все финансовые значения хранятся в минимальных денежных единицах.
- Заказ поддерживает несколько скидок.
- Заказ поддерживает промокоды.
- Заказ поддерживает чаевые.
- Заказ является источником данных для Analytics.

---

# Related Documents

PB-305 Product Requirements

DB-607 Menu & Product Schema

ARC-504 Event Driven Architecture

END OF DOCUMENT