---
Document ID: DB-605

Document Name: CUSTOMER SCHEMA

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

# CUSTOMER SCHEMA

## Purpose

Определяет структуру хранения данных клиентов SHIK Platform.

---

# Tables

- customers
- customer_addresses
- customer_devices
- customer_preferences
- customer_favorites
- customer_loyalty_accounts
- customer_notification_settings

---

# customers

Purpose

Основной профиль клиента.

Columns

- id
- user_id
- first_name
- last_name
- birth_date
- gender
- avatar_url
- preferred_language
- preferred_branch_id
- registration_source
- status
- created_at
- updated_at
- deleted_at
- created_by
- updated_by
- version

Indexes

- user_id
- preferred_branch_id
- status

---

# customer_addresses

Purpose

Адреса доставки.

Columns

- id
- customer_id
- title
- country
- city
- street
- house
- apartment
- entrance
- floor
- intercom
- latitude
- longitude
- comment
- is_default
- created_at
- updated_at

Indexes

- customer_id
- is_default

---

# customer_devices

Purpose

Устройства клиента.

Columns

- id
- customer_id
- platform
- device_name
- app_version
- push_token
- last_seen_at
- trusted
- created_at

Platforms

- iOS
- Android
- Web

---

# customer_preferences

Purpose

Предпочтения клиента.

Columns

- id
- customer_id
- language
- favorite_branch_id
- dark_mode
- marketing_enabled
- created_at
- updated_at

---

# customer_notification_settings

Purpose

Настройки коммуникаций.

Columns

- id
- customer_id
- push_enabled
- email_enabled
- sms_enabled
- whatsapp_enabled
- in_app_enabled
- marketing_consent
- quiet_hours_enabled
- created_at
- updated_at

---

# customer_favorites

Purpose

Избранные товары.

Columns

- id
- customer_id
- product_id
- created_at

Indexes

- customer_id
- product_id

---

# customer_loyalty_accounts

Purpose

Баланс программы лояльности.

Columns

- id
- customer_id
- loyalty_level_id
- balance
- lifetime_points
- total_orders
- created_at
- updated_at

---

# Relationships

users

↓

customers

↓

customer_addresses

↓

customer_devices

↓

customer_preferences

↓

customer_notification_settings

↓

customer_favorites

↓

customer_loyalty_accounts

---

# Constraints

- Один клиент → один профиль.
- Один клиент → много адресов.
- Один клиент → много устройств.
- Только один адрес может быть основным.
- Только одна запись настроек коммуникаций.

---

# Security

Protected Data

- Personal Data
- Addresses
- Device Information

Rules

- Soft Delete
- Audit Enabled
- RBAC Protected

---

# Related Documents

DB-604 Identity Schema

PB-305 Product Requirements

ARC-513 Communication Architecture

END OF DOCUMENT