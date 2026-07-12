---
Document ID: DB-606

Document Name: RESTAURANT & BRANCH SCHEMA

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

# RESTAURANT & BRANCH SCHEMA

## Purpose

Определяет структуру ресторанов, филиалов и их настроек.

---

# Tables

- restaurants
- branches
- branch_settings
- working_hours
- holidays
- delivery_zones
- payment_settings
- communication_settings
- map_provider_settings

---

# restaurants

Purpose

Сеть ресторанов.

Columns

- id
- name
- legal_name
- tax_number
- email
- phone
- website
- currency
- timezone
- status
- created_at
- updated_at
- deleted_at

---

# branches

Purpose

Филиалы ресторана.

Columns

- id
- restaurant_id
- name
- code
- phone
- email
- address
- latitude
- longitude
- status
- created_at
- updated_at

Indexes

- restaurant_id
- code

---

# branch_settings

Purpose

Общие настройки филиала.

Columns

- id
- branch_id
- default_language
- default_currency
- accepts_delivery
- accepts_pickup
- accepts_dine_in
- created_at
- updated_at

---

# working_hours

Columns

- id
- branch_id
- weekday
- opens_at
- closes_at
- is_closed

---

# holidays

Columns

- id
- branch_id
- date
- title
- is_closed

---

# delivery_zones

Columns

- id
- branch_id
- name
- delivery_fee
- minimum_order
- free_delivery_from
- estimated_minutes
- polygon
- is_active

---

# payment_settings

Columns

- id
- branch_id
- cash_enabled
- card_enabled
- sbp_enabled
- apple_pay_enabled
- google_pay_enabled
- provider

---

# communication_settings

Columns

- id
- branch_id
- push_enabled
- email_enabled
- sms_enabled
- whatsapp_enabled
- telegram_enabled
- quiet_hours_enabled

---

# map_provider_settings

Purpose

Настройка карт для филиала.

Columns

- id
- branch_id
- provider
- api_key_reference
- enabled
- created_at
- updated_at

Providers

- Google Maps
- Яндекс Карты
- 2GIS

---

# Relationships

restaurants

↓

branches

↓

working_hours

↓

holidays

↓

delivery_zones

↓

branch_settings

↓

payment_settings

↓

communication_settings

↓

map_provider_settings

---

# Business Rules

- Один ресторан → много филиалов.
- Каждый филиал имеет собственные настройки.
- Каждый филиал может использовать своего картографического провайдера.
- Каждый филиал имеет собственные зоны доставки.
- Каждый филиал имеет собственные способы оплаты.
- Каждый филиал имеет собственные правила коммуникаций.
- Каждый филиал имеет собственное расписание.

---

# Related Documents

ARC-505 Domain Model

ARC-513 Communication Architecture

PB-305 Product Requirements

END OF DOCUMENT