---
Document ID: BE-910

Document Name: DELIVERY SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# DELIVERY SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Delivery Service.

---

# Responsibilities

- Courier Management
- Delivery Assignment
- Route Calculation
- ETA Calculation
- Live Tracking
- Delivery Status Management
- Geolocation Processing

---

# Public API

- Deliveries
- Couriers
- Routes
- Tracking
- ETA
- Delivery Events

---

# Dependencies

- Order Service
- Restaurant Service
- Employee Service
- Communication Service
- Analytics Service
- Audit Service

---

# Database

Tables

- deliveries
- couriers
- courier_locations
- delivery_routes
- delivery_events
- delivery_history

---

# Map Providers

- Google Maps
- Яндекс Карты
- 2GIS

---

# Events Published

- CourierAssigned
- CourierAccepted
- DeliveryStarted
- CourierLocationUpdated
- DeliveryArrived
- DeliveryCompleted
- DeliveryCancelled

---

# Events Consumed

- OrderReady
- OrderCancelled
- BranchSettingsUpdated

---

# Delivery Workflow

- Pending
- Courier Assigned
- Accepted
- Picked Up
- On The Way
- Arrived
- Delivered
- Cancelled

---

# Business Rules

- Один заказ имеет одну активную доставку.
- Один курьер может вести несколько заказов согласно настройкам.
- ETA пересчитывается автоматически.
- Геолокация обновляется в реальном времени.
- Картографический сервис определяется настройками филиала.
- Все изменения статусов журналируются.
- Все события публикуются через Event Bus.

---

# Transactions

Atomic Operations

- Assign Courier
- Start Delivery
- Complete Delivery
- Cancel Delivery

Rollback

Required On Failure

---

# Security

- JWT
- RBAC
- Branch Isolation
- Audit Logging
- GPS Validation

---

# Background Jobs

- ETA Recalculation
- Route Optimization
- Courier Location Cleanup
- Delivery Statistics Update

---

# Error Codes

- DELIVERY_NOT_FOUND
- COURIER_NOT_FOUND
- ROUTE_NOT_FOUND
- INVALID_STATUS
- INVALID_LOCATION
- MAP_PROVIDER_UNAVAILABLE
- ACCESS_DENIED

---

# Performance

- Courier Assignment ≤ 300 ms
- ETA Calculation ≤ 1 sec
- Location Update ≤ 100 ms
- Tracking Refresh Real-Time

---

# Related Documents

API-710 Delivery API

DB-608 Order Schema

BE-909 Kitchen Service

ARC-504 Event-Driven Architecture

END OF DOCUMENT