---
Document ID: BE-903

Document Name: AUTHENTICATION SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# AUTHENTICATION SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Authentication Service.

---

# Responsibilities

- User Authentication
- JWT Management
- Refresh Token Rotation
- OTP Verification
- Password Management
- Session Management
- Device Management

---

# Public API

- Register
- Login
- Logout
- Logout All
- Refresh Token
- Send OTP
- Verify OTP
- Forgot Password
- Reset Password
- Current User
- Sessions

---

# Dependencies

- Identity Service
- Customer Service
- Employee Service
- Communication Service
- Audit Service

---

# Database

Tables

- users
- user_sessions
- otp_codes
- refresh_tokens

---

# Events Published

- UserRegistered
- UserLoggedIn
- UserLoggedOut
- PasswordChanged
- OTPVerified
- SessionRevoked

---

# Events Consumed

- CustomerCreated
- EmployeeCreated
- AccountBlocked

---

# Business Rules

- Один Refresh Token активен на одну сессию.
- JWT имеет ограниченный срок жизни.
- Refresh Token ротируется после каждого обновления.
- OTP имеет ограниченное время действия.
- Пароли хранятся только в виде Argon2 Hash.
- Все входы журналируются.
- Все устройства отслеживаются.

---

# Security

- JWT
- Argon2
- RBAC
- Rate Limiting
- Device Fingerprinting
- Audit Logging

---

# Background Jobs

- OTP Cleanup
- Expired Session Cleanup
- Refresh Token Cleanup

---

# Error Codes

- INVALID_CREDENTIALS
- INVALID_OTP
- OTP_EXPIRED
- TOKEN_EXPIRED
- TOKEN_INVALID
- ACCOUNT_LOCKED
- ACCOUNT_DISABLED

---

# Performance

- Login ≤ 300 ms
- Token Refresh ≤ 150 ms
- OTP Verification ≤ 200 ms

---

# Related Documents

API-703 Authentication API

DB-604 Identity Schema

ARC-514 Security Architecture

END OF DOCUMENT