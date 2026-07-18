---
Document ID: API-714

Document Name: COMMUNICATION API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# COMMUNICATION API

## Purpose

Определяет REST API Communication Automation Center.

---

# Base Endpoint

```text
/communication
```

---

# Channels

## GET /communication/channels

Purpose

Получить список каналов.

Authentication

JWT

---

## GET /communication/providers

Purpose

Получить список провайдеров.

Authentication

JWT

---

# Templates

## GET /communication/templates

Purpose

Получить шаблоны.

Supports

- Channel
- Language
- Branch

---

## GET /communication/templates/{id}

Purpose

Получить шаблон.

---

## POST /communication/templates

Purpose

Создать шаблон.

Permission

communication.template.create

---

## PATCH /communication/templates/{id}

Purpose

Изменить шаблон.

Permission

communication.template.update

---

## DELETE /communication/templates/{id}

Purpose

Архивировать шаблон.

Permission

communication.template.delete

---

# Rules

## GET /communication/rules

Purpose

Получить правила автоматизации.

---

## POST /communication/rules

Purpose

Создать правило.

Permission

communication.rule.create

---

## PATCH /communication/rules/{id}

Purpose

Изменить правило.

Permission

communication.rule.update

---

## DELETE /communication/rules/{id}

Purpose

Удалить правило.

Permission

communication.rule.delete

---

# Messages

## GET /communication/messages

Purpose

Получить журнал сообщений.

Supports

- Channel
- Status
- Recipient
- Branch
- Date Range

---

## GET /communication/messages/{id}

Purpose

Получить сообщение.

---

## POST /communication/messages/send

Purpose

Отправить сообщение вручную.

Permission

communication.send

Request

- channel
- recipient
- template_id
- variables
- scheduled_at

---

## POST /communication/messages/{id}/retry

Purpose

Повторить отправку.

Permission

communication.retry

---

## POST /communication/messages/{id}/cancel

Purpose

Отменить отправку.

Permission

communication.cancel

---

# Queue

## GET /communication/queue

Purpose

Получить очередь сообщений.

---

## POST /communication/queue/{id}/process

Purpose

Запустить обработку вручную.

---

# Delivery Logs

## GET /communication/delivery-logs

Purpose

Получить журнал доставки.

Supports

- Provider
- Channel
- Status
- Date Range

---

# Notification Preferences

## GET /communication/preferences/{customerId}

Purpose

Получить настройки клиента.

---

## PATCH /communication/preferences/{customerId}

Purpose

Изменить настройки клиента.

---

# Webhooks

## POST /communication/webhooks/{provider}

Purpose

Получить webhook от провайдера.

Authentication

Signature Verification

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

# Message Status

- Queued
- Processing
- Sent
- Delivered
- Read
- Failed
- Cancelled

---

# Validation Rules

- Все сообщения проходят через очередь.
- Шаблон обязателен для автоматических сообщений.
- Канал определяется правилами Communication Center.
- Выполняется проверка пользовательских настроек.
- Повторная отправка ограничена Retry Policy.
- Все сообщения журналируются.

---

# Events

- NotificationQueued
- NotificationSent
- NotificationDelivered
- NotificationRead
- NotificationFailed
- RetryStarted
- RetryCompleted

---

# Error Codes

- TEMPLATE_NOT_FOUND
- RULE_NOT_FOUND
- CHANNEL_NOT_AVAILABLE
- PROVIDER_UNAVAILABLE
- MESSAGE_NOT_FOUND
- DELIVERY_FAILED
- INVALID_RECIPIENT
- ACCESS_DENIED

---

# Security

- JWT Required
- RBAC
- Provider Signature Validation
- Audit Logging
- Rate Limiting

---

# Related Documents

DB-614 Communication Schema

ARC-513 Communication Architecture

PB-306 Communication Automation Center

ADR-006 Unified Communication Automation Center

END OF DOCUMENT