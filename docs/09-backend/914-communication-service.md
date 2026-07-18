---
Document ID: BE-914

Document Name: COMMUNICATION SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# COMMUNICATION SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Communication Service.

---

# Responsibilities

- Notification Management
- Message Queue
- Template Management
- Automation Rules
- Delivery Tracking
- Retry Processing
- Channel Selection
- Provider Integration

---

# Public API

- Templates
- Messages
- Notification Rules
- Delivery Logs
- Communication Settings
- Queue Management

---

# Dependencies

- Customer Service
- Order Service
- Payment Service
- Loyalty Service
- Employee Service
- Audit Service

---

# Database

Tables

- communication_templates
- communication_rules
- notifications
- notification_queue
- delivery_logs
- providers
- communication_settings
- message_variables

---

# Supported Channels

- Push
- In-App
- WhatsApp Business
- Telegram
- Email
- SMS
- Webhook

---

# Events Published

- NotificationQueued
- NotificationSent
- NotificationDelivered
- NotificationRead
- NotificationFailed
- RetryStarted
- RetryCompleted

---

# Events Consumed

- OrderCreated
- OrderConfirmed
- PaymentSucceeded
- OrderReady
- DeliveryStarted
- DeliveryCompleted
- LoyaltyPointsEarned
- CustomerRegistered

---

# Business Rules

- Все сообщения проходят через очередь.
- Канал определяется правилами Communication Automation Center.
- Пользовательские настройки обязательны к проверке.
- Поддерживается несколько каналов для одного события.
- При отказе канала применяется Retry Policy.
- Поддерживается Fallback Channel.
- WhatsApp Business используется только при согласии клиента.
- Все сообщения журналируются.
- Все события публикуются через Event Bus.

---

# Retry Policy

Attempts

- 3

Strategy

- Exponential Backoff

Fallback

- Next Available Channel

---

# Transactions

Atomic Operations

- Queue Message
- Send Notification
- Update Delivery Status
- Retry Notification

Rollback

Required On Failure

---

# Security

- JWT
- RBAC
- Provider Signature Validation
- Audit Logging
- Rate Limiting

---

# Background Jobs

- Queue Processing
- Retry Failed Messages
- Cleanup Old Notifications
- Delivery Status Synchronization
- Template Cache Refresh

---

# Error Codes

- TEMPLATE_NOT_FOUND
- RULE_NOT_FOUND
- MESSAGE_NOT_FOUND
- CHANNEL_UNAVAILABLE
- PROVIDER_UNAVAILABLE
- DELIVERY_FAILED
- INVALID_RECIPIENT
- ACCESS_DENIED

---

# Performance

- Queue Processing ≤ 100 ms
- Notification Dispatch ≤ 1 sec
- Delivery Update ≤ 500 ms
- Retry Scheduling ≤ 100 ms

---

# Related Documents

API-714 Communication API

DB-614 Communication Schema

PB-306 Communication Automation Center

ADR-006 Unified Communication Automation Center

ARC-513 Communication Architecture

END OF DOCUMENT