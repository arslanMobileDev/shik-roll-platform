---
Document ID: BE-902

Document Name: BACKEND CODING STANDARDS

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# BACKEND CODING STANDARDS

## Purpose

Определяет единые стандарты разработки Backend SHIK Platform.

---

# Technology

- NestJS
- TypeScript
- Prisma ORM
- PostgreSQL

---

# Architecture Rules

- Clean Architecture
- Domain Driven Design
- SOLID
- Dependency Injection
- Modular Structure
- Event-Driven Ready

---

# Module Structure

Every module contains

- controller
- service
- repository
- dto
- entity
- mapper
- validator
- events
- interfaces
- tests

---

# Naming Convention

Classes

- PascalCase

Methods

- camelCase

Variables

- camelCase

Constants

- UPPER_CASE

Files

- kebab-case

---

# Controllers

Responsibilities

- HTTP
- Validation
- Authorization
- Response Mapping

Must Not

- Business Logic
- Database Access

---

# Services

Responsibilities

- Business Logic
- Transactions
- Domain Rules

Must Not

- HTTP Logic

---

# Repositories

Responsibilities

- Database Access
- Queries
- Persistence

Must Not

- Business Logic

---

# DTO

Rules

- One DTO Per Operation
- Validation Required
- Immutable

---

# Validation

Library

- class-validator

Rules

- Validate All Input
- Sanitize Input
- Reject Invalid Data

---

# Error Handling

Use

- Global Exception Filter

Custom Exceptions

- BusinessException
- ValidationException
- NotFoundException
- UnauthorizedException
- ForbiddenException

---

# Logging

Log

- Errors
- Warnings
- Business Events
- Performance

Do Not Log

- Passwords
- Tokens
- Payment Data

---

# Transactions

Use Database Transactions

Required For

- Orders
- Payments
- Inventory
- Loyalty

---

# Events

Naming

- OrderCreated
- PaymentSucceeded
- CustomerRegistered

Rules

- Immutable
- Versioned
- Serializable

---

# Testing

Required

- Unit Tests
- Integration Tests
- E2E Tests

Coverage

Minimum 90%

---

# Documentation

Every Public Method

Must Include

- Description
- Parameters
- Return Value

---

# Security

- JWT
- RBAC
- Input Validation
- Output Validation
- Audit Logging

---

# Performance

- Avoid N+1 Queries
- Pagination Required
- Cache When Appropriate
- Async Processing

---

# Related Documents

BE-901 Backend Overview

ARC-505 Domain Model

ARC-514 Security Architecture

END OF DOCUMENT