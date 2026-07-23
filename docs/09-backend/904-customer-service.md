---
Document ID: BE-904

Document Name: CUSTOMER SERVICE

Book: Backend Specification

Version: 1.1.0

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
- Consent Management
- Legal Acceptance Evidence
- Data Subject Requests
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
- Manage Separate Consents
- Submit Data Subject Requests
- Get Legal Acceptance History
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
- legal_documents
- customer_consents
- customer_legal_acceptances
- data_subject_requests
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
- ConsentGranted
- ConsentWithdrawn
- DataSubjectRequestCreated

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
- Consent evidence is versioned and immutable.
- Marketing consent is separate from channel preferences and disabled by default.
- Data-subject requests require identity verification and an audit trail.

---

# Security

- JWT
- RBAC
- Audit Logging
- Soft Delete
- Input Validation
- Personal Data Localization
- Consent Evidence Integrity

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
- CONSENT_VERSION_INVALID
- DATA_REQUEST_ALREADY_OPEN

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

CMP-1908 Russian Personal Data & Consumer Legal Requirements

END OF DOCUMENT