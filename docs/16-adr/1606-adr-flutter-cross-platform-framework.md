---
Document ID: ADR-1606

Document Name: ADR — FLUTTER AS CROSS-PLATFORM FRAMEWORK

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

# ADR — FLUTTER AS CROSS-PLATFORM FRAMEWORK

## Status

Accepted

---

# Context

SHIK Platform включает несколько клиентских приложений:

- Customer App
- Courier App
- POS
- Kitchen Display System
- Back Office
- Owner Dashboard

Необходимо использовать единую технологию разработки пользовательских приложений.

---

# Problem

Основные варианты:

- Flutter
- React Native
- Kotlin Multiplatform
- .NET MAUI
- Native Development (Swift + Kotlin)

Требования

- Cross-Platform Development
- High Performance
- Consistent UI
- Shared Business Logic
- Modern Architecture
- Long-Term Support

---

# Decision

Использовать **Flutter** как основной фреймворк для разработки всех клиентских приложений SHIK Platform.

---

# Rationale

Flutter обеспечивает:

- единый код для iOS, Android, Web, Windows и macOS;
- высокую производительность благодаря компиляции в нативный код;
- собственный UI-движок;
- единый дизайн интерфейсов;
- быструю разработку;
- Hot Reload;
- зрелую экосистему;
- отличную интеграцию с REST API.

---

# Applications Covered

Mobile

- Customer App
- Courier App

Desktop

- POS
- Kitchen Display
- Back Office
- Owner Dashboard

Future

- Self-Service Kiosk
- Digital Signage
- Customer Display

---

# Alternatives Considered

## React Native

Advantages

- Большая экосистема
- JavaScript

Disadvantages

- Зависимость от Native Bridge
- Более сложная поддержка Desktop
- Более неоднородный UI

---

## Kotlin Multiplatform

Advantages

- Общая бизнес-логика
- Native UI

Disadvantages

- Раздельная разработка интерфейсов
- Меньше готовых решений
- Более сложная поддержка Web/Desktop

---

## .NET MAUI

Advantages

- Единый стек
- Хорошая интеграция с Microsoft

Disadvantages

- Более молодая экосистема
- Не соответствует выбранному стеку TypeScript + Dart

---

## Native Development

Advantages

- Максимальная производительность
- Полный доступ к платформе

Disadvantages

- Две независимые кодовые базы
- Более высокая стоимость разработки
- Более сложная поддержка

---

# Consequences

Positive

- Single Codebase
- Consistent UI
- Faster Development
- Lower Maintenance Cost
- Shared Components
- Shared Business Logic
- Excellent Desktop Support

Negative

- Зависимость от Flutter SDK
- Более крупный размер приложения
- Некоторые платформенные возможности требуют Native Plugins

---

# Risks

- Изменения экосистемы Flutter
- Ограничения отдельных платформ
- Зависимость от сторонних плагинов

Mitigation

- Использовать официальные пакеты
- Минимизировать платформенно-зависимый код
- Регулярно обновлять Flutter SDK
- Поддерживать собственные адаптеры для критичных интеграций

---

# Architecture Principles

- Feature-Based Structure
- Clean Architecture
- MVVM
- Repository Pattern
- Dependency Injection
- State Management
- Offline Ready
- Localization Ready

---

# Approved Packages

- go_router
- flutter_bloc
- dio
- freezed
- json_serializable
- get_it
- injectable
- hive
- flutter_secure_storage
- intl

---

# Success Criteria

- Единая кодовая база
- Высокая производительность
- Единый пользовательский опыт
- Простое масштабирование приложений
- Минимизация стоимости сопровождения

---

# Review Criteria

Пересмотр решения возможен при:

- прекращении активной поддержки Flutter;
- существенном изменении требований платформ;
- появлении технологий с явным преимуществом по стоимости владения и производительности.

---

# Related Documents

UI-801 Frontend Overview

UI-802 DESIGN SYSTEM

ARC-508 Technology Stack

DEV-1202 Repository Structure

END OF DOCUMENT