---
Document ID: DB-604

Document Name: IDENTITY SCHEMA

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

# IDENTITY SCHEMA

## Purpose

Определяет структуру домена Identity.

---

# Tables

- users
- roles
- permissions
- user_roles
- role_permissions
- sessions
- refresh_tokens
- otp_codes
- devices

---

# users

Purpose

Хранение учетных записей.

Columns

- id
- phone
- email
- password_hash
- first_name
- last_name
- avatar_url
- language
- status
- email_verified_at
- phone_verified_at
- last_login_at
- created_at
- updated_at
- deleted_at
- created_by
- updated_by
- version

Indexes

- phone
- email
- status

---

# roles

Columns

- id
- code
- name
- description
- created_at
- updated_at

Examples

- owner
- manager
- cashier
- cook
- courier
- customer
- administrator

---

# permissions

Columns

- id
- code
- name
- module
- description

Examples

- order.view
- order.create
- order.update
- payment.refund
- inventory.manage
- communication.manage

---

# user_roles

Columns

- id
- user_id
- role_id
- branch_id

Purpose

Связь пользователей с ролями и филиалами.

---

# role_permissions

Columns

- id
- role_id
- permission_id

Purpose

Связь ролей и разрешений.

---

# sessions

Columns

- id
- user_id
- device_id
- ip_address
- user_agent
- expires_at
- revoked_at
- created_at

Purpose

Активные пользовательские сессии.

---

# refresh_tokens

Columns

- id
- user_id
- token_hash
- expires_at
- revoked_at
- created_at

Purpose

Обновление JWT.

---

# otp_codes

Columns

- id
- phone
- code_hash
- purpose
- expires_at
- attempts
- created_at

Purpose

OTP-коды.

Purposes

- login
- registration
- password_reset
- phone_change

---

# devices

Columns

- id
- user_id
- platform
- device_name
- app_version
- push_token
- trusted
- last_seen_at

Platforms

- iOS
- Android
- Web

---

# Relationships

users

↓

user_roles

↓

roles

↓

role_permissions

↓

permissions

---

users

↓

sessions

↓

devices

---

users

↓

refresh_tokens

---

# Constraints

- phone UNIQUE
- email UNIQUE
- role code UNIQUE
- permission code UNIQUE

---

# Security Rules

- Passwords → Argon2
- Tokens → Hash Only
- OTP → Hash Only
- HTTPS Required
- Soft Delete Enabled

---

# Related Documents

DB-601 Database Overview

DB-602 Database Standards

ARC-514 Security Architecture

PB-305 Product Requirements

END OF DOCUMENT