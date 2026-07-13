---
Document ID: BE-904

Document Name: CUSTOMER SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# CUSTOMER SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Customer Service.

---

# Responsibilities

- Customer Profile
- Addresses
- Favorite Products
- Devices
- Preferences
- Notification Settings
- Loyalty Account

---

# Public API

- Get Profile
- Update Profile
- Manage Addresses
- Manage Favorites
- Manage Preferences
- Manage Devices
- Manage Notification Settings
- Get Loyalty Information

---

# Dependencies

- Authentication Service
- Loyalty Service
- Communication Service
- Order Service
- Audit Service

---

# Database

Tables

- customers
- customer_addresses
- customer_devices
- customer_preferences
- customer_favorites
- customer_notification_settings
- customer_loyalty_accounts

---

# Events Published

- CustomerCreated
- CustomerUpdated
- AddressCreated
- AddressUpdated
- AddressDeleted
- FavoriteAdded
- FavoriteRemoved
- NotificationSettingsUpdated

---

# Events Consumed

- UserRegistered
- OrderCompleted
- LoyaltyUpdated

---

# Business Rules

- Один пользователь имеет один профиль клиента.
- Один клиент может иметь несколько адресов.
- Только один адрес может быть основным.
- Избранное хранится отдельно для каждого клиента.
- Настройки уведомлений применяются перед отправкой сообщений.
- Все изменения профиля журналируются.

---

# Security

- JWT
- RBAC
- Audit Logging
- Soft Delete
- Input Validation

---

# Background Jobs

- Favorite Recommendations Update
- Inactive Device Cleanup
- Customer Statistics Update

---

# Error Codes

- CUSTOMER_NOT_FOUND
- ADDRESS_NOT_FOUND
- DEVICE_NOT_FOUND
- FAVORITE_NOT_FOUND
- VALIDATION_ERROR
- ACCESS_DENIED

---

# Performance

- Profile ≤ 200 ms
- Address Update ≤ 200 ms
- Favorites ≤ 150 ms

---

# Related Documents

API-704 Customer API

DB-605 Customer Schema

BE-903 Authentication Service

END OF DOCUMENT