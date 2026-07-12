---
Document ID: API-708

Document Name: PAYMENT API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# PAYMENT API

## Purpose

Определяет REST API для обработки платежей, возвратов и финансовых операций.

---

# Base Endpoint

```text
/payments
```

---

# Payment Endpoints

## POST /payments

Purpose

Создать платеж.

Authentication

JWT

Headers

- Idempotency-Key

Request

- order_id
- payment_method
- amount

Response

- payment
- payment_url
- expires_at

---

## GET /payments/{id}

Purpose

Получить информацию о платеже.

Authentication

JWT

---

## POST /payments/{id}/confirm

Purpose

Подтвердить платеж.

Authentication

JWT

---

## POST /payments/{id}/cancel

Purpose

Отменить платеж.

Authentication

JWT

---

## POST /payments/{id}/refund

Purpose

Выполнить возврат.

Authentication

JWT

Permission

payment.refund

Request

- amount
- reason

---

## GET /payments/{id}/transactions

Purpose

Получить историю транзакций.

Authentication

JWT

---

## GET /payments/{id}/receipt

Purpose

Получить фискальный чек.

Authentication

JWT

---

## GET /payments/providers

Purpose

Получить доступные платежные провайдеры.

Authentication

Public

---

## GET /payments/methods

Purpose

Получить доступные способы оплаты.

Authentication

Public

---

## POST /payments/webhooks/{provider}

Purpose

Webhook от платежного провайдера.

Authentication

Signature Verification

---

# Payment Methods

- Cash
- Bank Card
- Apple Pay
- Google Pay
- SBP
- Loyalty Points
- Gift Certificate

---

# Supported Providers

- CloudPayments
- ЮKassa
- SBP
- Stripe (Future)

---

# Payment Status

- Pending
- Authorized
- Paid
- Failed
- Cancelled
- Refunded
- Partially Refunded

---

# Transaction Types

- Authorization
- Capture
- Payment
- Refund
- Cancellation

---

# Validation Rules

- платеж привязан к одному заказу;
- сумма возврата не может превышать сумму оплаты;
- повторный платеж защищен Idempotency-Key;
- статус обновляется только через Payment Service;
- webhook проходит обязательную проверку подписи.

---

# Events

- PaymentCreated
- PaymentAuthorized
- PaymentSucceeded
- PaymentFailed
- RefundCreated
- RefundCompleted

---

# Error Codes

- PAYMENT_NOT_FOUND
- PAYMENT_FAILED
- PAYMENT_ALREADY_COMPLETED
- PAYMENT_ALREADY_REFUNDED
- INVALID_PAYMENT_METHOD
- INVALID_PROVIDER
- REFUND_LIMIT_EXCEEDED
- PROVIDER_UNAVAILABLE
- INVALID_SIGNATURE
- VALIDATION_ERROR

---

# Security

- HTTPS Only
- JWT
- Idempotency
- Provider Signature Validation
- Audit Logging
- PCI DSS Ready

---

# Related Documents

DB-609 Payment Schema

API-707 Order API

ARC-514 Security Architecture

PB-305 Product Requirements

END OF DOCUMENT