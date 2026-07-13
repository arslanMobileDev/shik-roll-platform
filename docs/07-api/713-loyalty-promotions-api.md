---
Document ID: API-713

Document Name: LOYALTY & PROMOTIONS API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# LOYALTY & PROMOTIONS API

## Purpose

Определяет REST API программы лояльности, бонусов, акций, купонов и подарочных сертификатов.

---

# Base Endpoint

```text
/loyalty
/promotions
```

---

# Loyalty

## GET /loyalty/account

Purpose

Получить бонусный счет клиента.

Authentication

JWT

---

## GET /loyalty/transactions

Purpose

Получить историю бонусных операций.

Authentication

JWT

Supports

- Pagination
- Date Range

---

## GET /loyalty/levels

Purpose

Получить уровни программы лояльности.

Authentication

Public

---

## POST /loyalty/redeem

Purpose

Использовать бонусы при оформлении заказа.

Authentication

JWT

Request

- order_id
- points

---

# Promotions

## GET /promotions

Purpose

Получить активные акции.

Authentication

Public

Supports

- Branch
- Category

---

## GET /promotions/{id}

Purpose

Получить информацию об акции.

---

## POST /promotions

Purpose

Создать акцию.

Permission

promotion.create

---

## PATCH /promotions/{id}

Purpose

Изменить акцию.

Permission

promotion.update

---

## DELETE /promotions/{id}

Purpose

Архивировать акцию.

Permission

promotion.delete

---

# Coupons

## POST /promotions/coupons/validate

Purpose

Проверить промокод.

Authentication

JWT

Request

- code
- order_id

Response

- valid
- discount
- promotion

---

## POST /promotions/coupons/apply

Purpose

Применить промокод.

Authentication

JWT

Request

- code
- order_id

---

## DELETE /promotions/coupons/{code}

Purpose

Удалить промокод из заказа.

Authentication

JWT

---

# Gift Certificates

## GET /gift-certificates/{code}

Purpose

Проверить сертификат.

Authentication

JWT

---

## POST /gift-certificates/redeem

Purpose

Использовать сертификат.

Authentication

JWT

Request

- code
- order_id

---

# Administration

## GET /admin/loyalty/accounts

Permission

loyalty.view

---

## POST /admin/loyalty/adjustment

Purpose

Ручная корректировка бонусов.

Permission

loyalty.adjust

Request

- customer_id
- points
- reason

---

## GET /admin/promotions

Permission

promotion.view

---

# Loyalty Transaction Types

- Earn
- Redeem
- Expire
- Refund
- Adjustment

---

# Promotion Types

- Percentage Discount
- Fixed Discount
- Buy X Get Y
- Combo Offer
- Cashback
- Free Delivery

---

# Validation Rules

- Баланс бонусов не может быть отрицательным.
- Купон проверяется перед оформлением заказа.
- Один купон используется согласно установленным ограничениям.
- Акции могут быть ограничены филиалом.
- Сертификат не может быть использован после окончания срока действия.
- Все бонусные операции журналируются.

---

# Events

- LoyaltyPointsAdded
- LoyaltyPointsRedeemed
- LoyaltyLevelChanged
- CouponApplied
- CouponRejected
- PromotionActivated
- PromotionExpired

---

# Error Codes

- LOYALTY_ACCOUNT_NOT_FOUND
- INSUFFICIENT_POINTS
- INVALID_COUPON
- COUPON_EXPIRED
- PROMOTION_NOT_FOUND
- GIFT_CERTIFICATE_NOT_FOUND
- GIFT_CERTIFICATE_EXPIRED
- ACCESS_DENIED

---

# Security

- JWT Required
- RBAC
- Audit Logging
- Rate Limiting

---

# Related Documents

DB-613 Loyalty & Promotions Schema

API-707 Order API

PB-305 Product Requirements

END OF DOCUMENT