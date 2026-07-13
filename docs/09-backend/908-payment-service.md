---
Document ID: BE-908

Document Name: PAYMENT SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# PAYMENT SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Payment Service.

---

# Responsibilities

- Payment Processing
- Payment Authorization
- Payment Capture
- Refund Processing
- Payment Verification
- Fiscal Receipt Management
- Payment Provider Integration
- Payment Audit

---

# Public API

- Create Payment
- Confirm Payment
- Cancel Payment
- Refund Payment
- Payment Status
- Transactions
- Fiscal Receipts
- Payment Methods

---

# Dependencies

- Order Service
- Customer Service
- Loyalty Service
- Communication Service
- Analytics Service
- Audit Service

---

# Database

Tables

- payments
- payment_transactions
- payment_methods
- payment_providers
- refunds
- fiscal_receipts
- invoices
- payment_audit

---

# Payment Providers

- CloudPayments
- ЮKassa
- SBP
- Stripe (Future)

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

# Events Published

- PaymentCreated
- PaymentAuthorized
- PaymentCaptured
- PaymentSucceeded
- PaymentFailed
- RefundCreated
- RefundCompleted
- FiscalReceiptIssued

---

# Events Consumed

- OrderCreated
- OrderCancelled
- OrderRefundRequested

---

# Business Rules

- Один платеж относится к одному заказу.
- Один заказ может содержать несколько платежных транзакций.
- Поддерживается частичный возврат.
- Поддерживается комбинированная оплата.
- Все суммы хранятся в минимальных денежных единицах.
- Все операции проходят проверку Idempotency-Key.
- Webhook обрабатывается только после проверки цифровой подписи.
- Финансовые записи не удаляются.
- Все изменения записываются в Audit.

---

# Transactions

Atomic Operations

- Payment Authorization
- Payment Capture
- Refund Processing
- Receipt Generation

Rollback

Required On Failure

---

# Security

- HTTPS
- JWT
- RBAC
- PCI DSS Ready
- Tokenized Payments
- Audit Logging
- Provider Signature Validation

---

# Background Jobs

- Payment Status Synchronization
- Refund Processing
- Receipt Generation
- Failed Payment Retry

---

# Error Codes

- PAYMENT_NOT_FOUND
- PAYMENT_FAILED
- PAYMENT_ALREADY_COMPLETED
- PAYMENT_ALREADY_REFUNDED
- INVALID_PAYMENT_METHOD
- INVALID_PROVIDER
- INVALID_SIGNATURE
- REFUND_LIMIT_EXCEEDED
- PROVIDER_UNAVAILABLE
- ACCESS_DENIED

---

# Performance

- Payment Creation ≤ 300 ms
- Authorization ≤ 2 sec
- Refund ≤ 3 sec
- Webhook Processing ≤ 500 ms

---

# Related Documents

API-708 Payment API

DB-609 Payment Schema

BE-907 Order Service

ARC-514 Security Architecture

END OF DOCUMENT