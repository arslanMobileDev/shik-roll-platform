---
Document ID: ADR-1608

Document Name: ADR — CLEAN ARCHITECTURE & MODULAR MONOLITH READY

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

# ADR — CLEAN ARCHITECTURE & MODULAR MONOLITH READY

## Status

Accepted

---

# Context

SHIK Platform должна поддерживать быстрое развитие продукта на ранних этапах и возможность масштабирования до распределенной архитектуры без полного переписывания системы.

Платформа включает десятки бизнес-доменов:

- Authentication
- Customers
- Restaurants
- Menu
- Orders
- Payments
- Kitchen
- Delivery
- Inventory
- Loyalty
- Communication
- Analytics
- AI

Необходимо выбрать архитектурный подход, который обеспечит баланс между простотой разработки и долгосрочной масштабируемостью.

---

# Problem

Основные варианты:

- Traditional Layered Architecture
- Clean Architecture
- Hexagonal Architecture
- Full Domain-Driven Design
- Immediate Microservices

Требования

- Высокая сопровождаемость
- Независимость бизнес-логики
- Простое тестирование
- Минимальная связанность модулей
- Возможность постепенного перехода к микросервисам

---

# Decision

Использовать **Clean Architecture** с модульной структурой приложения.

На начальном этапе платформа реализуется как **Modular Monolith**, архитектурно готовый к эволюционному переходу в микросервисную архитектуру.

---

# Rationale

Выбранный подход обеспечивает:

- независимость бизнес-логики;
- слабую связанность модулей;
- четкие границы ответственности;
- простое тестирование;
- возможность выделения любого модуля в отдельный сервис без изменения Domain Layer;
- снижение стоимости разработки на раннем этапе проекта.

---

# Architecture Layers

Core

- Domain

Application

- Use Cases
- Services

Infrastructure

- Database
- Queue
- External APIs

Presentation

- REST API
- Webhooks
- Background Jobs

---

# Module Structure

Each Module Contains

- Controller
- DTO
- Service
- Domain
- Repository
- Events
- Validators
- Tests

---

# Dependency Rules

Allowed

Presentation

↓

Application

↓

Domain

Infrastructure implements interfaces defined in Domain/Application.

Forbidden

- Domain → Infrastructure
- Domain → Framework
- Domain → Database
- Cross-module direct database access

---

# Domain Principles

- Business Rules First
- Framework Independent
- Database Independent
- Testable
- Technology Agnostic

---

# Alternatives Considered

## Traditional Layered Architecture

Advantages

- Простота
- Быстрое начало разработки

Disadvantages

- Высокая связанность
- Сложность масштабирования
- Размытые границы ответственности

---

## Full Domain-Driven Design

Advantages

- Максимальная гибкость
- Богатая доменная модель

Disadvantages

- Высокая сложность
- Большие затраты на разработку
- Избыточно для текущего масштаба

---

## Immediate Microservices

Advantages

- Независимые сервисы
- Максимальная масштабируемость

Disadvantages

- Очень высокая эксплуатационная сложность
- Большое количество инфраструктуры
- Медленная разработка на старте

---

# Consequences

Positive

- Clean Module Boundaries
- High Testability
- Independent Business Logic
- Easier Refactoring
- Evolutionary Architecture
- Lower Technical Debt

Negative

- Более строгая архитектурная дисциплина
- Дополнительные абстракции
- Более высокий порог входа для новых разработчиков

---

# Risks

- Нарушение границ модулей
- Избыточные зависимости
- Перегруженные сервисы

Mitigation

- ADR Reviews
- Architecture Reviews
- Static Analysis
- Module Dependency Validation
- Code Review

---

# Migration Strategy

Current

- Modular Monolith

Future

- Extract Independent Modules
- Replace Internal Calls With Events
- Separate Databases Where Needed
- Independent Deployment

No Business Logic Rewrite Required

---

# Success Criteria

- Независимые модули
- Минимальная связанность
- Простое тестирование
- Простое выделение сервисов
- Высокая сопровождаемость

---

# Review Criteria

Пересмотр решения возможен при:

- кардинальном изменении бизнес-модели;
- переходе к полностью распределенной архитектуре;
- появлении новых требований к масштабированию.

---

# Related Documents

ARC-502 MODULAR ARCHITECTURE

ARC-503 MICROSERVICES STRATEGY

ADR-1602 Monorepo Architecture

ADR-1603 Event-Driven Architecture

BE-901 Backend Overview

END OF DOCUMENT