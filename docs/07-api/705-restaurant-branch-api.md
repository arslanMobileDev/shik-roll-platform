---
Document ID: API-705

Document Name: RESTAURANT & BRANCH API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# RESTAURANT & BRANCH API

## Purpose

Определяет REST API управления ресторанами, филиалами и их настройками.

---

# Base Endpoint

```
/restaurants
```

---

# Restaurant Endpoints

## GET /restaurants

Purpose

Получить список ресторанов.

Authentication

JWT

---

## GET /restaurants/{id}

Purpose

Получить ресторан.

Authentication

JWT

---

## POST /restaurants

Purpose

Создать ресторан.

Authentication

JWT

Permission

restaurant.create

---

## PATCH /restaurants/{id}

Purpose

Изменить ресторан.

Authentication

JWT

Permission

restaurant.update

---

## DELETE /restaurants/{id}

Purpose

Архивировать ресторан.

Authentication

JWT

Permission

restaurant.delete

---

# Branch Endpoints

## GET /branches

Purpose

Получить список филиалов.

---

## GET /branches/{id}

Purpose

Получить филиал.

---

## POST /branches

Purpose

Создать филиал.

Permission

branch.create

---

## PATCH /branches/{id}

Purpose

Изменить филиал.

Permission

branch.update

---

## DELETE /branches/{id}

Purpose

Архивировать филиал.

Permission

branch.delete

---

## GET /branches/{id}/working-hours

Purpose

Получить график работы.

---

## PATCH /branches/{id}/working-hours

Purpose

Обновить график работы.

---

## GET /branches/{id}/delivery-zones

Purpose

Получить зоны доставки.

---

## POST /branches/{id}/delivery-zones

Purpose

Создать зону доставки.

---

## PATCH /branches/{id}/delivery-zones/{zoneId}

Purpose

Изменить зону доставки.

---

## DELETE /branches/{id}/delivery-zones/{zoneId}

Purpose

Удалить зону доставки.

---

## GET /branches/{id}/settings

Purpose

Получить настройки филиала.

---

## PATCH /branches/{id}/settings

Purpose

Изменить настройки филиала.

---

## GET /branches/{id}/payment-settings

Purpose

Получить способы оплаты.

---

## PATCH /branches/{id}/payment-settings

Purpose

Изменить способы оплаты.

---

## GET /branches/{id}/communication-settings

Purpose

Получить настройки Communication Automation Center.

---

## PATCH /branches/{id}/communication-settings

Purpose

Изменить настройки Communication Automation Center.

---

## GET /branches/{id}/map-provider

Purpose

Получить картографический сервис.

---

## PATCH /branches/{id}/map-provider

Purpose

Изменить картографический сервис.

Request

- provider

Providers

- Google Maps
- Яндекс Карты
- 2GIS

---

# Error Codes

- RESTAURANT_NOT_FOUND
- BRANCH_NOT_FOUND
- DELIVERY_ZONE_NOT_FOUND
- INVALID_PROVIDER
- ACCESS_DENIED
- VALIDATION_ERROR

---

# Security

- JWT Required
- RBAC
- Branch Isolation
- Audit Logging

---

# Related Documents

DB-606 Restaurant & Branch Schema

ARC-505 Domain Model

PB-305 Product Requirements

END OF DOCUMENT