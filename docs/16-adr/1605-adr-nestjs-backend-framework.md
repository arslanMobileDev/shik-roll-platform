---
Document ID: ADR-1605

Document Name: ADR — NESTJS AS BACKEND FRAMEWORK

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: July 2026
Last Updated: July 2026


Classification: Internal
---

# ADR — NESTJS AS BACKEND FRAMEWORK

## Status

Accepted

---

# Context

SHIK Platform представляет собой модульную платформу с большим количеством сервисов:

- Authentication
- Customer
- Menu
- Order
- Payment
- Kitchen
- Delivery
- Inventory
- Loyalty
- Analytics
- AI Gateway

Необходимо выбрать основной backend framework.

---

# Problem

Основные варианты:

- NestJS
- Express
- Fastify
- Spring Boot
- ASP.NET Core

Требования

- TypeScript First
- Modular Architecture
- Dependency Injection
- Enterprise Ready
- Microservices Support
- Excellent Testing
- Long-Term Maintainability

---

# Decision

Использовать **NestJS** как основной backend framework SHIK Platform.

---

# Rationale

NestJS обеспечивает:

- архитектуру уровня Enterprise;
- встроенный Dependency Injection;
- модульную организацию проекта;
- отличную поддержку TypeScript;
- простое тестирование;
- встроенную поддержку Validation;
- поддержку REST, GraphQL, WebSocket и Microservices;
- хорошую интеграцию с Prisma ORM;
- зрелую экосистему.

---

# Alternatives Considered

## Express

Advantages

- Простота
- Огромная экосистема

Disadvantages

- Нет архитектуры "из коробки"
- Требуется самостоятельно строить DI
- Сложнее сопровождать большие проекты

---

## Fastify

Advantages

- Очень высокая производительность
- Низкое потребление памяти

Disadvantages

- Более ограниченная экосистема
- Требуется самостоятельно проектировать архитектуру

---

## Spring Boot

Advantages

- Enterprise Ready
- Богатая экосистема
- Отличная поддержка больших систем

Disadvantages

- Java Stack
- Более высокий порог входа
- Не соответствует выбранному TypeScript стеку

---

## ASP.NET Core

Advantages

- Высокая производительность
- Enterprise возможности

Disadvantages

- C#
- Другая технологическая экосистема
- Не соответствует выбранному стеку

---

# Consequences

Positive

- Unified TypeScript Stack
- Strong Modular Architecture
- Excellent Testability
- Built-in Validation
- Dependency Injection
- Clean Code Structure
- Easy Team Scaling

Negative

- Более высокий уровень абстракции
- Требуется понимание DI
- Более сложный старт для новичков

---

# Risks

- Переусложнение небольших сервисов
- Некорректное использование Dependency Injection
- Рост количества модулей

Mitigation

- Coding Standards
- Architecture Review
- Module Boundaries
- ADR Documentation

---

# Architecture Principles

- Feature Modules
- Controller → Service → Repository
- Dependency Injection
- DTO Validation
- Global Exception Filters
- Interceptors
- Guards
- Pipes

---

# Supporting Libraries

Approved

- Prisma ORM
- class-validator
- class-transformer
- Swagger
- Passport
- JWT
- BullMQ
- RabbitMQ Client

---

# Testing Strategy

Required

- Unit Tests
- Integration Tests
- API Tests
- E2E Tests

---

# Success Criteria

- Высокая сопровождаемость
- Простое масштабирование сервисов
- Единая архитектура
- Высокая скорость разработки
- Простое подключение новых разработчиков

---

# Review Criteria

Пересмотр решения возможен при:

- существенном изменении требований платформы;
- отказе от TypeScript;
- появлении новых архитектурных ограничений.

---

# Related Documents

BE-901 Backend Overview

BE-902 Backend Coding Standards

DEV-1202 Repository Structure

ARC-508 Technology Stack

END OF DOCUMENT