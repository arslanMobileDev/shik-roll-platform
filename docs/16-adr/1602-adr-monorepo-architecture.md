---
Document ID: ADR-1602

Document Name: ADR — MONOREPO ARCHITECTURE

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: July 2026

Classification: Internal
---

# ADR — MONOREPO ARCHITECTURE

## Status

Accepted

---

# Context

SHIK Platform состоит из большого количества приложений, сервисов, библиотек и документации:

- Customer App
- Courier App
- POS
- Kitchen Display
- Back Office
- Owner Dashboard
- Backend API
- Workers
- Shared Packages
- Documentation

Требовалось выбрать стратегию хранения исходного кода.

---

# Problem

Основные варианты:

- Monorepo
- Polyrepo

Необходимо обеспечить:

- единое версионирование;
- повторное использование кода;
- единые стандарты разработки;
- простую автоматизацию CI/CD;
- масштабирование команды.

---

# Decision

Использовать **Monorepo** как основную архитектуру репозитория SHIK Platform.

---

# Rationale

Monorepo обеспечивает:

- единый процесс разработки;
- централизованное управление зависимостями;
- повторное использование shared packages;
- единый CI/CD pipeline;
- единый процесс ревью;
- единые стандарты кодирования;
- синхронное версионирование всех компонентов.

---

# Alternatives Considered

## Polyrepo

Advantages

- Независимые релизы
- Простые небольшие проекты

Disadvantages

- Дублирование кода
- Сложные зависимости
- Сложный CI/CD
- Несогласованные версии
- Более высокая стоимость сопровождения

---

## Hybrid Repository

Advantages

- Частичная независимость

Disadvantages

- Повышенная сложность
- Неоднозначные границы ответственности
- Более сложная автоматизация

---

# Consequences

Positive

- Shared Libraries
- Unified Tooling
- Single CI/CD
- Consistent Architecture
- Faster Development
- Easier Refactoring

Negative

- Большой размер репозитория
- Более сложные первоначальные настройки CI
- Требуются инструменты управления workspace

---

# Risks

- Длительное время сборки
- Рост количества зависимостей
- Большое количество Pull Request

Mitigation

- Incremental Builds
- Build Cache
- Workspace Management
- Parallel CI Jobs

---

# Implementation

Repository Structure

- apps/
- packages/
- services/
- infrastructure/
- docs/
- scripts/
- tools/

Package Manager

- pnpm

Workspace

- pnpm-workspace.yaml

---

# Success Criteria

- Единый процесс сборки
- Повторное использование кода
- Отсутствие дублирования библиотек
- Централизованный CI/CD
- Простое масштабирование команды

---

# Review Criteria

Пересмотр решения возможен при:

- значительном росте команды;
- появлении независимых продуктов;
- изменении требований к инфраструктуре.

---

# Related Documents

DEV-1202 Repository Structure

DEV-1203 Git Workflow & Branching Strategy

ARC-508 Technology Stack

END OF DOCUMENT