---
Document ID: API-703

Document Name: AUTHENTICATION API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# AUTHENTICATION API

## Purpose

Определяет REST API аутентификации и управления пользовательскими сессиями.

---

# Base Endpoint

```
/auth
```

---

# Endpoints

## POST /auth/register

Purpose

Регистрация пользователя.

Authentication

Public

Request

- phone
- email
- password
- first_name
- last_name
- language

Response

- user
- access_token
- refresh_token

---

## POST /auth/login

Purpose

Вход в систему.

Authentication

Public

Request

- phone_or_email
- password

Response

- access_token
- refresh_token
- expires_at
- user

---

## POST /auth/refresh

Purpose

Обновление Access Token.

Authentication

Refresh Token

Request

- refresh_token

Response

- access_token
- expires_at

---

## POST /auth/logout

Purpose

Завершение текущей сессии.

Authentication

JWT

Response

- success

---

## POST /auth/logout-all

Purpose

Завершение всех активных сессий.

Authentication

JWT

Response

- success

---

## POST /auth/send-otp

Purpose

Отправка OTP.

Authentication

Public

Request

- phone
- purpose

Purposes

- login
- registration
- password_reset

---

## POST /auth/verify-otp

Purpose

Проверка OTP.

Authentication

Public

Request

- phone
- code

Response

- verified

---

## POST /auth/forgot-password

Purpose

Запрос восстановления пароля.

Authentication

Public

Request

- phone_or_email

---

## POST /auth/reset-password

Purpose

Смена пароля.

Authentication

OTP Required

Request

- token
- new_password

---

## GET /auth/me

Purpose

Получение информации о текущем пользователе.

Authentication

JWT

Response

- profile
- roles
- permissions
- branches

---

## GET /auth/sessions

Purpose

Получение списка активных устройств.

Authentication

JWT

Response

- devices

---

## DELETE /auth/sessions/{id}

Purpose

Завершение выбранной сессии.

Authentication

JWT

---

# Error Codes

- INVALID_CREDENTIALS
- INVALID_OTP
- OTP_EXPIRED
- USER_BLOCKED
- ACCOUNT_DISABLED
- TOKEN_EXPIRED
- TOKEN_INVALID
- SESSION_NOT_FOUND
- TOO_MANY_ATTEMPTS

---

# Security

- JWT
- Refresh Token Rotation
- Argon2 Password Hashing
- Rate Limiting
- Device Tracking
- Audit Logging

---

# Related Documents

API-701 API Overview

DB-604 Identity Schema

ARC-514 Security Architecture

END OF DOCUMENT