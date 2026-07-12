---
Document ID: API-704

Document Name: CUSTOMER API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# CUSTOMER API

## Purpose

Определяет REST API для управления профилем клиента.

---

# Base Endpoint

```
/customers
```

---

# Endpoints

## GET /customers/me

Purpose

Получить профиль текущего клиента.

Authentication

JWT

Response

- profile
- loyalty
- preferences

---

## PATCH /customers/me

Purpose

Обновить профиль.

Authentication

JWT

Request

- first_name
- last_name
- birth_date
- avatar_url
- language

---

## GET /customers/me/addresses

Purpose

Получить список адресов.

Authentication

JWT

---

## POST /customers/me/addresses

Purpose

Создать адрес.

Authentication

JWT

Request

- title
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

---

## PATCH /customers/me/addresses/{id}

Purpose

Изменить адрес.

Authentication

JWT

---

## DELETE /customers/me/addresses/{id}

Purpose

Удалить адрес.

Authentication

JWT

Soft Delete

---

## PATCH /customers/me/addresses/{id}/default

Purpose

Назначить основной адрес.

Authentication

JWT

---

## GET /customers/me/favorites

Purpose

Получить избранные товары.

Authentication

JWT

---

## POST /customers/me/favorites

Purpose

Добавить товар в избранное.

Authentication

JWT

Request

- product_id

---

## DELETE /customers/me/favorites/{productId}

Purpose

Удалить товар из избранного.

Authentication

JWT

---

## GET /customers/me/loyalty

Purpose

Получить бонусный счет.

Authentication

JWT

Response

- level
- balance
- lifetime_points
- transactions

---

## GET /customers/me/preferences

Purpose

Получить пользовательские настройки.

Authentication

JWT

---

## PATCH /customers/me/preferences

Purpose

Обновить настройки.

Authentication

JWT

Request

- language
- marketing_enabled
- favorite_branch_id

---

## GET /customers/me/notifications

Purpose

Получить настройки уведомлений.

Authentication

JWT

---

## PATCH /customers/me/notifications

Purpose

Обновить настройки уведомлений.

Authentication

JWT

Request

- push_enabled
- email_enabled
- sms_enabled
- whatsapp_enabled
- telegram_enabled
- marketing_enabled

---

## GET /customers/me/devices

Purpose

Получить список устройств.

Authentication

JWT

---

## DELETE /customers/me/devices/{id}

Purpose

Удалить устройство.

Authentication

JWT

---

# Error Codes

- CUSTOMER_NOT_FOUND
- ADDRESS_NOT_FOUND
- FAVORITE_NOT_FOUND
- DEVICE_NOT_FOUND
- VALIDATION_ERROR
- ACCESS_DENIED

---

# Security

- JWT Required
- RBAC
- Audit Logging
- Soft Delete
- Rate Limiting

---

# Related Documents

API-703 Authentication API

DB-605 Customer Schema

PB-305 Product Requirements

END OF DOCUMENT