---
Document ID: DB-609

Document Name: PAYMENT SCHEMA

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

# PAYMENT SCHEMA

## Purpose

Определяет структуру хранения платежей и финансовых операций.

---

# Tables

- payments
- payment_transactions
- payment_methods
- payment_providers
- refunds
- fiscal_receipts
- invoices
- payment_audit

---

# payments

Columns

- id
- order_id
- customer_id
- payment_method_id
- payment_provider_id
- amount
- currency
- status
- provider_reference
- authorized_at
- captured_at
- failed_at
- created_at
- updated_at

Indexes

- order_id
- customer_id
- status
- provider_reference

---

# payment_transactions

Columns

- id
- payment_id
- transaction_type
- amount
- provider_transaction_id
- status
- response_code
- response_message
- processed_at

---

# payment_methods

Columns

- id
- code
- name
- is_active

Methods

- Cash
- Bank Card
- Apple Pay
- Google Pay
- SBP
- Gift Certificate
- Loyalty Points

---

# payment_providers

Columns

- id
- code
- name
- status
- configuration_reference

Providers

- CloudPayments
- ЮKassa
- SBP
- Stripe (Future)

---

# refunds

Columns

- id
- payment_id
- amount
- reason
- status
- provider_reference
- processed_at

---

# fiscal_receipts

Columns

- id
- payment_id
- receipt_number
- fiscal_number
- provider_reference
- issued_at

---

# invoices

Columns

- id
- order_id
- invoice_number
- amount
- currency
- status
- issued_at
- due_at

---

# payment_audit

Columns

- id
- payment_id
- action
- user_id
- old_value
- new_value
- created_at

---

# Relationships

orders

↓

payments

↓

payment_transactions

↓

refunds

↓

fiscal_receipts

↓

payment_audit

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

# Business Rules

- Один заказ может иметь несколько платежных транзакций.
- Возврат связан с конкретным платежом.
- Все суммы хранятся в минимальных денежных единицах.
- Provider Reference уникален в рамках провайдера.
- Финансовые записи не удаляются.
- Все изменения фиксируются в Audit.
- Поддерживается частичный возврат средств.
- Поддерживается комбинированная оплата (например, бонусы + карта).

---

# Security

- Не хранить данные банковских карт.
- Не хранить CVV.
- Хранить только токены провайдера.
- Все секреты находятся в Secret Manager.
- Все операции выполняются по HTTPS.

---

# Related Documents

DB-608 Order Schema

ARC-514 Security Architecture

PB-305 Product Requirements

END OF DOCUMENT