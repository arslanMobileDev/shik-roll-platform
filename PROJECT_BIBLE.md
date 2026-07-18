---
Document ID: PB-002

Document Name: PROJECT BIBLE

Book: Foundation

Version: 2.0.0

Status: APPROVED

Project: SHIK Platform

First Brand: SHIK ROLL

Repository: SHIK-ROLL-PLATFORM

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

AI Software Engineer: Claude Code

AI Design Assistant: Claude Design

Last Updated: July 2026

Classification: Internal
---

# PROJECT BIBLE

## Purpose

PROJECT BIBLE является главным навигационным документом SHIK Platform Engineering Handbook.

Он определяет:

- стратегию платформы;
- структуру документации;
- жизненный цикл продукта;
- архитектурную карту;
- взаимосвязь между всеми документами Engineering Handbook.

PROJECT BIBLE не содержит детального описания отдельных модулей.

Для этого существуют специализированные документы.

---

# Product Vision

SHIK Platform — это облачная модульная платформа автоматизации ресторанного бизнеса.

Первым брендом платформы является SHIK ROLL.

Архитектура платформы проектируется таким образом, чтобы поддерживать:

- один ресторан;
- сеть ресторанов;
- несколько независимых брендов.

---

# Platform Layers

Платформа состоит из трех уровней.

## Layer 1 — Core Platform

Ядро платформы.

Содержит универсальные сервисы:

- Authentication
- Users
- Orders
- Menu
- Kitchen
- Delivery
- POS
- Inventory
- Loyalty
- Notifications
- Analytics
- Payments
- Integration Layer
- Map Provider Layer

Core Platform не содержит информации о конкретном ресторане.

---

## Layer 2 — Brand Layer

Все, что относится к бренду.

Для SHIK ROLL:

- логотип;
- фирменные цвета;
- фотографии;
- категории меню;
- маркетинговые материалы;
- тексты.

В будущем может существовать несколько Brand Layer.

---

## Layer 3 — Configuration Layer

Настройки, изменяемые владельцем через Back Office.

Например:

- меню;
- цены;
- акции;
- бонусы;
- фотографии;
- филиалы;
- зоны доставки;
- сотрудники;
- роли;
- стоп-листы;
- рабочее время.

Изменение Configuration Layer не требует изменения кода.

---

# Engineering Handbook Structure

Engineering Handbook состоит из восьми книг.

## Book 0

Navigation

---

## Book 1

Foundation

---

## Book 2

Business

---

## Book 3

Product

---

## Book 4

Brand & Design

---

## Book 5

Architecture

---

## Book 6

Engineering

---

## Book 7

Operations

---

## Book 8

Future

---

# Platform Modules

Платформа состоит из независимых модулей.

## Customer

Mobile Application

---

## Kitchen

Kitchen Display System

---

## Courier

Courier Application

---

## POS

Cashier Application

---

## Owner

Owner Dashboard

---

## Admin

Back Office

---

## Backend

Business Services

---

## Integrations

External Systems

---

# AI Development Workflow

Разработка платформы строится следующим образом.

Business

↓

Documentation

↓

Architecture

↓

Design

↓

Development

↓

Testing

↓

Deployment

↓

Support

AI используется на каждом этапе.

ChatGPT

↓

Claude Design

↓

Claude Code

---

# Documentation Workflow

Каждая новая функция проходит следующий путь.

Idea

↓

Documentation

↓

ADR

↓

Design

↓

Development

↓

Testing

↓

Release

---

# Architecture Principles

Подробные инженерные принципы находятся в:

PB-001 PROJECT_MANIFEST

---

# Architecture Decision Records

Все ключевые решения фиксируются через ADR.

Каталог:

docs/19-decisions/

---

# Repository Structure

SHIK-ROLL-PLATFORM/

README.md

PROJECT_BIBLE.md

PROJECT_MANIFEST.md

DECISIONS.md

docs/

design/

assets/

prompts/

apps/

packages/

scripts/

docker/

infrastructure/

---

# Product Lifecycle

Research

↓

Planning

↓

Design

↓

Development

↓

Testing

↓

Release

↓

Support

↓

Evolution

---

# Supported Map Providers

Платформа официально поддерживает:

- Google Maps
- Яндекс Карты
- 2GIS

Работа осуществляется через единый Map Provider Layer.

Добавление новых провайдеров не должно влиять на бизнес-логику.

---

# Technology Baseline

Mobile

Flutter

Backend

NestJS

Database

PostgreSQL

ORM

Prisma

Cache

Redis

Queues

BullMQ

Cloud

Google Cloud Platform

Authentication

Firebase Authentication

Notifications

Firebase Cloud Messaging

Admin

Next.js

---

# Engineering Rules

1. Documentation First

2. Design Before Development

3. API-First

4. Modular Architecture

5. Clean Architecture

6. Security By Design

7. Vendor Independence

8. Configuration First

9. AI Assisted Development

10. Continuous Documentation

---

# Related Documents

PB-001 PROJECT_MANIFEST

README

DECISIONS

ADR Repository

Engineering Handbook

---

# Golden Rule

Engineering Handbook является единственным источником истины для проекта SHIK Platform.

Если возникает противоречие между кодом, дизайном и документацией, приоритет имеет утвержденная документация.

---

END OF DOCUMENT