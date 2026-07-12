---
Document ID: DB-613

Document Name: LOYALTY & PROMOTIONS SCHEMA

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

# LOYALTY & PROMOTIONS SCHEMA

## Purpose

Определяет структуру программы лояльности, бонусов, купонов и маркетинговых акций.

---

# Tables

- loyalty_levels
- loyalty_accounts
- loyalty_transactions
- bonus_rules
- promotions
- promotion_rules
- promotion_products
- promotion_branches
- coupons
- coupon_redemptions
- gift_certificates

---

# loyalty_levels

Columns

- id
- code
- name
- minimum_points
- cashback_percent
- priority

---

# loyalty_accounts

Columns

- id
- customer_id
- loyalty_level_id
- current_points
- lifetime_points
- total_orders
- created_at
- updated_at

---

# loyalty_transactions

Columns

- id
- loyalty_account_id
- order_id
- transaction_type
- points
- balance_after
- expires_at
- created_at

---

# bonus_rules

Columns

- id
- branch_id
- rule_name
- order_percent
- fixed_points
- minimum_order
- starts_at
- ends_at
- is_active

---

# promotions

Columns

- id
- code
- name
- description
- priority
- starts_at
- ends_at
- is_active

---

# promotion_rules

Columns

- id
- promotion_id
- rule_type
- value
- minimum_order
- maximum_discount

---

# promotion_products

Columns

- id
- promotion_id
- product_id

---

# promotion_branches

Columns

- id
- promotion_id
- branch_id

---

# coupons

Columns

- id
- code
- promotion_id
- usage_limit
- used_count
- expires_at
- status

---

# coupon_redemptions

Columns

- id
- coupon_id
- customer_id
- order_id
- redeemed_at

---

# gift_certificates

Columns

- id
- code
- initial_balance
- current_balance
- expires_at
- status

---

# Relationships

customers

↓

loyalty_accounts

↓

loyalty_transactions

↓

orders

---

promotions

↓

promotion_rules

↓

promotion_products

↓

promotion_branches

↓

coupons

↓

coupon_redemptions

---

# Transaction Types

- Earn
- Redeem
- Expire
- Adjustment
- Refund

---

# Promotion Types

- Percentage
- Fixed Amount
- Combo
- Buy X Get Y
- Free Delivery
- Cashback

---

# Business Rules

- Один клиент имеет один Loyalty Account.
- Баланс бонусов не может быть отрицательным.
- Купон может иметь ограничения по использованию.
- Акции могут действовать только в выбранных филиалах.
- Правила начисления изменяются через Back Office.
- Все операции журналируются.
- Поддерживается комбинированное использование бонусов и оплаты.

---

# Related Documents

DB-605 Customer Schema

DB-608 Order Schema

PB-305 Product Requirements

END OF DOCUMENT