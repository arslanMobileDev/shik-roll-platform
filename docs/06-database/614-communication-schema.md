---
Document ID: DB-614

Document Name: COMMUNICATION SCHEMA

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

# COMMUNICATION SCHEMA

## Purpose

Определяет структуру данных Communication Automation Center.

---

# Tables

- communication_channels
- communication_providers
- communication_rules
- communication_templates
- template_variables
- message_queue
- messages
- delivery_logs
- notification_preferences
- webhook_subscriptions

---

# communication_channels

Columns

- id
- code
- name
- is_active

Channels

- Push
- In-App
- WhatsApp
- Telegram
- Email
- SMS
- Webhook

---

# communication_providers

Columns

- id
- channel_id
- code
- name
- configuration_reference
- priority
- is_active

---

# communication_rules

Columns

- id
- branch_id
- event_type
- channel_id
- template_id
- delay_seconds
- quiet_hours
- enabled

---

# communication_templates

Columns

- id
- channel_id
- language
- code
- title
- subject
- body
- version
- is_active

---

# template_variables

Columns

- id
- template_id
- variable_name
- description

---

# message_queue

Columns

- id
- event_type
- recipient
- channel_id
- provider_id
- template_id
- priority
- scheduled_at
- status
- retry_count
- created_at

---

# messages

Columns

- id
- queue_id
- customer_id
- branch_id
- content
- sent_at
- delivered_at
- read_at
- status

---

# delivery_logs

Columns

- id
- message_id
- provider_response
- response_code
- error_message
- retry_count
- created_at

---

# notification_preferences

Columns

- id
- customer_id
- push_enabled
- email_enabled
- sms_enabled
- whatsapp_enabled
- telegram_enabled
- marketing_enabled
- updated_at

---

# webhook_subscriptions

Columns

- id
- branch_id
- event_type
- endpoint
- secret_reference
- is_active

---

# Relationships

communication_rules

↓

communication_templates

↓

message_queue

↓

messages

↓

delivery_logs

---

customers

↓

notification_preferences

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

# Priority

- Low
- Normal
- High
- Critical

---

# Business Rules

- Все сообщения проходят через очередь.
- Канал выбирается по правилам Communication Center.
- Филиалы могут иметь собственные шаблоны.
- Поддерживается несколько провайдеров одного канала.
- При ошибке выполняется Retry Policy.
- Все отправки журналируются.
- Клиентские настройки имеют приоритет над маркетинговыми рассылками.

---

# Related Documents

PB-306 Communication Automation Center

ARC-513 Communication Architecture

DB-605 Customer Schema

END OF DOCUMENT