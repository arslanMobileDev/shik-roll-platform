---
Document ID: ADR-1609

Document Name: ADR — API-FIRST & CONTRACT-FIRST DEVELOPMENT

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

# ADR — API-FIRST & CONTRACT-FIRST DEVELOPMENT

## Status

Accepted

---

# Context

SHIK Platform включает множество клиентских приложений и внутренних сервисов:

- Customer App
- Courier App
- POS
- Kitchen Display
- Back Office
- Owner Dashboard
- Backend Services
- AI Gateway
- External Integrations

Все они взаимодействуют через REST API.

---

# Problem

Необходимо определить единый подход к проектированию API.

Основные варианты:

- Code First
- API First
- Contract First
- Database First

Требования

- Независимая разработка Frontend и Backend
- Строгие API-контракты
- Автоматическая генерация документации
- Генерация SDK
- Обратная совместимость API

---

# Decision

Использовать **API-First** с принципами **Contract-First Development**.

Контракт API создается и утверждается **до начала реализации**.

OpenAPI Specification является единственным источником истины (Single Source of Truth).

---

# Rationale

API-First обеспечивает:

- независимую работу команд;
- раннюю валидацию архитектуры;
- единые контракты;
- автоматическую генерацию документации;
- автоматическую генерацию SDK;
- снижение количества интеграционных ошибок.

---

# API Lifecycle

- Requirements
- Contract Design
- Architecture Review
- Contract Approval
- SDK Generation
- Backend Implementation
- Frontend Implementation
- Testing
- Release

---

# Contract Standards

Format

- OpenAPI 3.1

Documentation

- Swagger UI

Exchange Format

- JSON

---

# API Design Principles

- Resource Oriented
- RESTful
- Versioned
- Stateless
- Consistent Naming
- Standard HTTP Methods
- Standard Status Codes

---

# SDK Generation

Supported

- TypeScript
- Dart
- Kotlin (Future)
- Swift (Future)

Generated From

- OpenAPI Specification

---

# Versioning Policy

Pattern

- /api/v1/

Rules

- No Breaking Changes Within Version
- Deprecation Before Removal
- Version Lifecycle Documentation

---

# Backward Compatibility

Required

- Existing Clients Continue Working
- Deprecated Fields Supported During Transition
- New Fields Optional By Default

---

# Alternatives Considered

## Code First

Advantages

- Быстрый старт разработки

Disadvantages

- Контракт появляется слишком поздно
- Риск расхождения документации и реализации
- Более сложная интеграция команд

---

## Database First

Advantages

- Простота проектирования данных

Disadvantages

- API становится зависимым от структуры БД
- Слабая архитектурная гибкость

---

## GraphQL First

Advantages

- Гибкость запросов
- Минимизация объема данных

Disadvantages

- Более высокая сложность
- Не соответствует выбранной REST-архитектуре
- Избыточен для большинства сценариев платформы

---

# Consequences

Positive

- Stable Contracts
- Independent Teams
- Auto Generated SDK
- Better Documentation
- Easier Testing
- Reduced Integration Risks

Negative

- Требуется дополнительный этап проектирования
- Контракты необходимо поддерживать актуальными
- Более строгий процесс изменений

---

# Governance

Every API Change Requires

- Architecture Review
- OpenAPI Update
- Documentation Update
- SDK Regeneration
- Compatibility Verification

---

# Success Criteria

- Все API имеют OpenAPI-контракт
- Документация всегда соответствует реализации
- SDK генерируется автоматически
- Отсутствуют незадокументированные endpoints
- Минимум интеграционных ошибок

---

# Review Criteria

Пересмотр решения возможен при:

- переходе на GraphQL;
- изменении стратегии интеграции;
- появлении новых корпоративных требований к API.

---

# Related Documents

API-701 API Overview

API-702 API Standards

DEV-1204 CI/CD Pipeline Specification

ADR-1608 Clean Architecture & Modular Monolith Ready

END OF DOCUMENT