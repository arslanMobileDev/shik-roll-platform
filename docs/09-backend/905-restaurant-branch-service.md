---
Document ID: BE-905

Document Name: RESTAURANT & BRANCH SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# RESTAURANT & BRANCH SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Restaurant & Branch Service.

---

# Responsibilities

- Restaurant Management
- Branch Management
- Working Hours
- Holidays
- Delivery Zones
- Payment Settings
- Communication Settings
- Map Provider Settings

---

# Public API

- Restaurants
- Branches
- Working Hours
- Holidays
- Delivery Zones
- Branch Settings
- Payment Settings
- Communication Settings
- Map Provider Settings

---

# Dependencies

- Customer Service
- Order Service
- Delivery Service
- Communication Service
- Audit Service

---

# Database

Tables

- restaurants
- branches
- working_hours
- holidays
- delivery_zones
- branch_settings
- payment_settings
- communication_settings
- map_provider_settings

---

# Events Published

- RestaurantCreated
- RestaurantUpdated
- BranchCreated
- BranchUpdated
- BranchClosed
- DeliveryZoneUpdated
- WorkingHoursUpdated
- BranchSettingsUpdated

---

# Events Consumed

- OrderCreated
- BranchConfigurationChanged

---

# Business Rules

- Один ресторан содержит несколько филиалов.
- Каждый филиал имеет собственные настройки.
- Каждый филиал самостоятельно выбирает картографический сервис.
- Каждый филиал самостоятельно управляет способами оплаты.
- Каждый филиал самостоятельно управляет каналами коммуникации.
- Зоны доставки не должны пересекаться без явного разрешения.
- Изменение рабочего времени вступает в силу согласно настройкам публикации.

---

# Security

- JWT
- RBAC
- Branch Isolation
- Audit Logging
- Soft Delete

---

# Background Jobs

- Branch Status Synchronization
- Working Hours Validation
- Delivery Zone Cache Refresh

---

# Error Codes

- RESTAURANT_NOT_FOUND
- BRANCH_NOT_FOUND
- DELIVERY_ZONE_NOT_FOUND
- INVALID_WORKING_HOURS
- INVALID_MAP_PROVIDER
- ACCESS_DENIED

---

# Performance

- Branch Lookup ≤ 100 ms
- Settings Update ≤ 200 ms
- Delivery Zone Lookup ≤ 150 ms

---

# Related Documents

API-705 Restaurant & Branch API

DB-606 Restaurant & Branch Schema

BE-904 Customer Service

END OF DOCUMENT