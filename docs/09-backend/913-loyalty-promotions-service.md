---
Document ID: BE-913

Document Name: LOYALTY & PROMOTIONS SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# LOYALTY & PROMOTIONS SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Loyalty & Promotions Service.

---

# Responsibilities

- Loyalty Accounts
- Loyalty Levels
- Bonus Transactions
- Promotions
- Coupons
- Gift Certificates
- Cashback
- Discount Rules

---

# Public API

- Loyalty Accounts
- Loyalty Levels
- Bonus Transactions
- Promotions
- Coupons
- Gift Certificates
- Cashback

---

# Dependencies

- Customer Service
- Order Service
- Payment Service
- Communication Service
- Analytics Service
- Audit Service

---

# Database

Tables

- loyalty_accounts
- loyalty_levels
- loyalty_transactions
- promotions
- promotion_rules
- coupons
- coupon_redemptions
- gift_certificates
- cashback_transactions

---

# Events Published

- LoyaltyAccountCreated
- LoyaltyPointsEarned
- LoyaltyPointsRedeemed
- LoyaltyLevelChanged
- PromotionActivated
- PromotionExpired
- CouponApplied
- CouponRejected
- GiftCertificateRedeemed

---

# Events Consumed

- CustomerCreated
- OrderCompleted
- OrderRefunded
- PaymentSucceeded

---

# Business Rules

- Один клиент имеет один бонусный счет.
- Бонусы начисляются только после завершения заказа.
- Возврат заказа отменяет начисленные бонусы.
- Купоны проверяются перед оплатой.
- Один купон применяется согласно установленным ограничениям.
- Сертификаты могут использоваться частично.
- Акции могут быть ограничены филиалом, категорией, продуктом и периодом.
- Все операции журналируются.
- Все события публикуются через Event Bus.

---

# Transactions

Atomic Operations

- Earn Points
- Redeem Points
- Apply Coupon
- Redeem Gift Certificate
- Refund Bonus Points

Rollback

Required On Failure

---

# Security

- JWT
- RBAC
- Audit Logging
- Input Validation

---

# Background Jobs

- Loyalty Level Recalculation
- Promotion Activation
- Promotion Expiration
- Coupon Expiration
- Bonus Expiration

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

# Performance

- Bonus Calculation ≤ 100 ms
- Coupon Validation ≤ 150 ms
- Loyalty Update ≤ 200 ms
- Promotion Evaluation ≤ 300 ms

---

# Related Documents

API-713 Loyalty & Promotions API

DB-613 Loyalty & Promotions Schema

BE-907 Order Service

ARC-504 Event-Driven Architecture

END OF DOCUMENT