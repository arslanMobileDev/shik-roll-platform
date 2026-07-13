---
Document ID: API-710

Document Name: DELIVERY API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# DELIVERY API

## Purpose

Определяет REST API для управления доставкой, курьерами и маршрутами.

---

# Base Endpoint

```text
/delivery
```

---

# Delivery Endpoints

## GET /delivery/orders

Purpose

Получить активные доставки.

Authentication

JWT

Permission

delivery.view

Supports

- Branch
- Courier
- Status

---

## GET /delivery/orders/{id}

Purpose

Получить информацию о доставке.

Authentication

JWT

---

## POST /delivery/orders/{id}/assign

Purpose

Назначить курьера.

Permission

delivery.assign

Request

- courier_id

---

## POST /delivery/orders/{id}/start

Purpose

Начать доставку.

Permission

delivery.start

---

## POST /delivery/orders/{id}/arrived

Purpose

Курьер прибыл.

Permission

delivery.arrived

---

## POST /delivery/orders/{id}/complete

Purpose

Завершить доставку.

Permission

delivery.complete

---

## POST /delivery/orders/{id}/cancel

Purpose

Отменить доставку.

Permission

delivery.cancel

Request

- reason

---

# Couriers

## GET /delivery/couriers

Purpose

Получить список курьеров.

---

## POST /delivery/couriers

Purpose

Создать курьера.

Permission

courier.create

---

## PATCH /delivery/couriers/{id}

Purpose

Изменить данные курьера.

Permission

courier.update

---

## DELETE /delivery/couriers/{id}

Purpose

Архивировать курьера.

Permission

courier.delete

---

## PATCH /delivery/couriers/{id}/location

Purpose

Обновить геолокацию.

Authentication

JWT

Request

- latitude
- longitude
- heading
- speed

---

## GET /delivery/couriers/{id}/location

Purpose

Получить текущую геолокацию.

---

# Routes

## GET /delivery/routes/{id}

Purpose

Получить маршрут доставки.

---

## POST /delivery/routes/calculate

Purpose

Рассчитать маршрут.

Request

- origin
- destination
- provider

Providers

- Google Maps
- Яндекс Карты
- 2GIS

---

# Tracking

## GET /delivery/tracking/{orderId}

Purpose

Получить статус доставки для клиента.

Authentication

JWT

Response

- status
- courier
- eta
- location

---

# Delivery Status

- Pending
- Courier Assigned
- Picked Up
- On The Way
- Arrived
- Delivered
- Cancelled

---

# Validation Rules

- Один заказ — один активный курьер.
- Геолокация обновляется только назначенным курьером.
- ETA пересчитывается автоматически.
- Маршрут определяется настройками филиала.
- Все изменения статусов журналируются.

---

# Events

- CourierAssigned
- CourierStarted
- CourierLocationUpdated
- CourierArrived
- OrderDelivered

---

# Error Codes

- DELIVERY_NOT_FOUND
- COURIER_NOT_FOUND
- ROUTE_NOT_FOUND
- INVALID_STATUS
- INVALID_LOCATION
- PROVIDER_UNAVAILABLE
- ACCESS_DENIED

---

# Security

- JWT Required
- RBAC
- Branch Isolation
- Audit Logging
- GPS Validation

---

# Related Documents

DB-606 Restaurant & Branch Schema

DB-608 Order Schema

ARC-504 Event Driven Architecture

PB-305 Product Requirements

END OFDOCUMENT