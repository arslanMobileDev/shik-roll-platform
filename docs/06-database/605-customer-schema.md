---
Document ID: DB-605

Document Name: CUSTOMER SCHEMA

Book: Database

Version: 1.1.0

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
- legal_documents
- customer_consents
- customer_legal_acceptances
- data_subject_requests

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
- quiet_hours_enabled
- created_at
- updated_at

---

# legal_documents

Purpose

Неизменяемые версии юридических документов.

Columns

- id
- document_type
- version
- locale
- status
- content_hash
- effective_at
- published_at
- superseded_at
- created_by
- created_at

---

# customer_consents

Purpose

Отдельные доказательства согласий и их отзыва.

Columns

- id
- customer_id
- purpose
- legal_document_id
- legal_document_version
- legal_document_hash
- status
- granted_at
- withdrawn_at
- source
- ip_address
- user_agent
- evidence_id
- created_at

---

# customer_legal_acceptances

Purpose

Доказательство ознакомления или принятия юридического документа, включая публичную оферту.

Columns

- id
- customer_id
- order_id
- legal_document_id
- legal_document_version
- legal_document_hash
- accepted_at
- source
- ip_address
- user_agent
- evidence_id
- created_at

---

# data_subject_requests

Purpose

Запросы субъекта персональных данных.

Columns

- id
- customer_id
- request_type
- status
- requested_at
- verified_at
- completed_at
- rejection_reason
- audit_reference
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

customer_consents / customer_legal_acceptances / data_subject_requests

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
- Каждое согласие хранится как отдельная версионированная запись.
- Published legal document and acceptance records are immutable.
- Marketing consent is never inferred from notification preferences.

---

# Security

Protected Data

- Personal Data
- Addresses
- Device Information
- Consent Evidence
- Legal Acceptance Evidence
- Data Subject Requests

Rules

- Soft Delete
- Audit Enabled
- RBAC Protected

---

# Related Documents

DB-604 Identity Schema

PB-305 Product Requirements

ARC-513 Communication Architecture

CMP-1908 Russian Personal Data & Consumer Legal Requirements

END OF DOCUMENT