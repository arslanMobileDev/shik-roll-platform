# SHIK ROLL Platform
## PROJECT BIBLE

---

**Document Version:** 1.0.0

**Document Status:** Draft

**Project:** SHIK ROLL Platform

**Product Owner:** Arslan Berslanov

**Technical Architect:** OpenAI ChatGPT

**Primary AI Development Assistant:** Claude Code

**Primary AI Design Assistant:** Claude Design

**Repository:** SHIK-ROLL-PLATFORM

**Created:** July 2026

---

# Purpose

PROJECT BIBLE является главным документом платформы SHIK ROLL.

Он описывает:

- стратегию продукта;
- архитектурные принципы;
- цели проекта;
- правила разработки;
- структуру документации;
- этапы развития платформы.

Этот документ НЕ содержит детального описания отдельных модулей.

Все подробности находятся в документах Product Book.

---

# Vision

Создать современную облачную платформу автоматизации ресторанов быстрого питания нового поколения.

Платформа должна позволять ресторану работать полностью независимо от сторонних систем автоматизации и при необходимости интегрироваться с ними.

---

# Mission

Упростить управление рестораном.

Сделать процесс заказа быстрым для клиента.

Упростить работу персонала.

Предоставить владельцу полный контроль над бизнесом в режиме реального времени.

---

# Core Principles

Проект строится на следующих принципах.

## 1. Cloud First

Все сервисы работают через облачную инфраструктуру Google Cloud.

---

## 2. Mobile First

Все основные процессы должны быть доступны с мобильных устройств.

---

## 3. Modular Architecture

Каждый модуль платформы является независимым.

Например:

- Client App
- Kitchen App
- Courier App
- Admin Panel
- Owner Dashboard
- Manager App
- Backend API

Каждый модуль развивается отдельно.

---

## 4. API First

Любое взаимодействие происходит через Backend API.

Никаких прямых подключений между приложениями.

---

## 5. Feature First

Функции разрабатываются по бизнес-модулям.

Например:

Authentication

↓

Menu

↓

Orders

↓

Kitchen

↓

Delivery

↓

Analytics

---

## 6. AI Assisted Development

Проект создается совместно с AI.

Claude Code отвечает за разработку.

Claude Design отвечает за дизайн.

ChatGPT отвечает за архитектуру продукта.

---

## 7. Documentation First

Сначала документация.

Потом дизайн.

Потом код.

Потом тестирование.

Потом публикация.

---

## 8. Scalable Platform

Архитектура сразу должна поддерживать:

• одну точку;

• несколько филиалов;

• сеть ресторанов.

---

## 9. Vendor Independence

Платформа не должна зависеть от конкретной POS-системы.

Quick Resto

iiko

Poster

r_keeper

являются только возможными интеграциями.

---

## 10. Maintainability

Каждый модуль должен иметь возможность развиваться независимо.

---

# Technology Stack

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

Queues

BullMQ

Authentication

Firebase Auth

Cloud

Google Cloud Platform

Storage

Google Cloud Storage

Notifications

Firebase Cloud Messaging

Admin

Next.js

---

# Map Provider Layer

Платформа поддерживает несколько картографических сервисов.

Google Maps

Яндекс Карты

2GIS

Архитектура должна позволять добавлять новые сервисы без изменения бизнес-логики.

---

# Integration Layer

В платформе существует отдельный слой интеграций.

Он используется для подключения:

Quick Resto

iiko

Poster

r_keeper

1С

Telegram

Email

Платежных систем

Агрегаторов доставки

---

# Product Modules

Client App

Kitchen App

Courier App

Admin Panel

Owner Dashboard

Manager App

Backend API

Integration Layer

---

# Documentation Structure

PROJECT_BIBLE.md

PROJECT_MANIFEST.md

README.md

DECISIONS.md

CHANGELOG.md

CONTRIBUTING.md

Product Book

Business

Brand

Menu

Architecture

Database

API

Security

Deployment

Support

Roadmap

---

# Development Workflow

Product Book

↓

Design

↓

Architecture Review

↓

Development

↓

Testing

↓

Release

↓

Support

---

# Release Strategy

MVP

↓

Version 1.0

↓

Version 1.5

↓

Version 2.0

↓

Version 3.0

---

# Roadmap

Подробная дорожная карта находится в:

docs/17-roadmap/

---

# Related Documents

README.md

PROJECT_MANIFEST.md

DECISIONS.md

docs/

---

# Golden Rule

Ни одна строка production-кода не пишется до тех пор, пока не завершен Product Book.

---

END OF DOCUMENT