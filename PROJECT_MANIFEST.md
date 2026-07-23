---
Document ID: PB-001

Document Name: PROJECT MANIFEST

Version: 1.2.0

Status: APPROVED

Project: SHIK Platform

First Brand: SHIK ROLL

Repository: SHIK-ROLL-PLATFORM

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

AI Software Engineer: Claude Code

AI UI/UX Designer: Claude Design

Last Updated: July 2026

Classification: Internal
---

# PROJECT MANIFEST

## Purpose

PROJECT MANIFEST определяет неизменные инженерные принципы платформы SHIK Platform.

Этот документ является "Конституцией" проекта.

Любое архитектурное решение должно соответствовать данным принципам.

Если возникает необходимость нарушить один из принципов — сначала создается новый ADR (Architecture Decision Record), после чего принимается коллективное решение.

---

# Mission

Создать современную облачную платформу автоматизации ресторанного бизнеса, которая позволяет полностью управлять заведением независимо от сторонних систем автоматизации и при необходимости интегрироваться с ними.

---

# Vision

Построить модульную SaaS-платформу, которая станет технологическим ядром для одного ресторана, сети ресторанов и в перспективе — для различных брендов общественного питания.

---

# Engineering Principles

## EP-001 Documentation First

Ни одна функция не реализуется до появления утвержденной документации.

Документация является первоисточником требований.

---

## EP-002 Design Before Development

Любой пользовательский интерфейс сначала проектируется Claude Design.

После утверждения дизайн передается Claude Code.

---

## EP-003 Architecture Before Code

Архитектурное решение принимается раньше написания кода.

Все ключевые решения фиксируются через ADR.

---

## EP-004 Clean Architecture

Все приложения платформы используют Clean Architecture.

Бизнес-логика не зависит от UI, базы данных или сторонних сервисов.

---

## EP-005 Modular Platform

Каждый модуль развивается независимо.

Примеры модулей:

- Authentication
- Menu
- Orders
- Kitchen
- Delivery
- POS
- Inventory
- HR
- Analytics
- Loyalty

---

## EP-006 API-First

Все приложения работают только через Backend API.

Прямое взаимодействие между приложениями запрещено.

---

## EP-007 Backend Owns Business Logic

Вся бизнес-логика находится исключительно в Backend.

Мобильные приложения содержат только клиентскую логику.

---

## EP-008 Vendor Independence

Платформа не зависит от конкретного поставщика услуг.

Quick Resto, iiko, Poster, r_keeper, Stripe и другие рассматриваются исключительно как интеграции.

---

## EP-009 Cloud-Native

Текущей production-платформой является Beget Cloud в российском регионе.

Архитектура сохраняет provider-neutral границы, контейнерную переносимость и готовность к горизонтальному масштабированию.

---

## EP-010 AI Assisted Development

AI является частью процесса разработки.

Роли распределяются следующим образом:

- ChatGPT — архитектура, документация, стратегия.
- Claude Code — разработка.
- Claude Design — UI/UX.
- BMad Method — бизнес-анализ.
- Pointail — повышение эффективности разработки (при необходимости).

---

## EP-011 Security By Design

Безопасность учитывается на этапе проектирования.

Каждая новая функция проходит проверку требований безопасности.

---

## EP-012 Scalability

Платформа должна поддерживать:

- одну точку;
- несколько филиалов;
- сеть ресторанов;
- несколько брендов.

Без изменения архитектуры.

---

## EP-013 Maintainability

Любой модуль можно заменить без переписывания всей системы.

---

## EP-014 Testability

Каждый модуль должен проектироваться таким образом, чтобы его можно было автоматически тестировать.

---

## EP-015 Observability

Каждый сервис должен поддерживать:

- логирование;
- мониторинг;
- трассировку ошибок;
- метрики.

---

## EP-016 Offline Tolerance

Критически важные приложения (POS, Kitchen) должны продолжать работать при кратковременной потере соединения с интернетом с последующей синхронизацией данных.

---

## EP-017 Multi Map Provider

Платформа использует слой Map Provider.

Поддерживаемые сервисы:

- Google Maps
- Яндекс Карты
- 2GIS

В будущем допускается подключение:

- Apple Maps
- HERE Maps
- OpenStreetMap

Без изменения бизнес-логики платформы.

---

## EP-018 Product Independence

SHIK Platform является самостоятельным программным продуктом.

SHIK ROLL — первый бренд, использующий платформу.

---

# Technology Baseline

Frontend

Flutter

Backend

NestJS

Database

PostgreSQL

ORM

Prisma

Cache

Redis

Background Jobs

BullMQ

Event Bus

RabbitMQ

Cloud

Beget Cloud

Runtime

Beget Cloud VPS with Docker Compose

Authentication

Firebase Authentication (Candidate; production use requires CMP-1908 compliance gate and a separate architecture decision)

Notifications

Firebase Cloud Messaging

Storage

Beget S3 through the S3-Compatible Adapter

Back Office / Owner Dashboard

Flutter Web

---

# Architecture Decision Records

Все архитектурные решения фиксируются через ADR.

Каталог:

docs/16-adr/

---

# Golden Rule

Если существует сомнение —

сначала обновляется документация,

потом архитектура,

потом дизайн,

и только после этого пишется код.

---

# Approval

После получения статуса APPROVED данный документ считается обязательным для всех участников проекта.

---

# Related Documents

- PB-002 — PROJECT BIBLE
- PB-109 — TERMINOLOGY GLOSSARY
- ARC-501 — SYSTEM OVERVIEW
- ADR-1600 — ARCHITECTURE DECISION RECORDS INDEX
- GOV-2707 — DOCUMENT REGISTRY

---

END OF DOCUMENT