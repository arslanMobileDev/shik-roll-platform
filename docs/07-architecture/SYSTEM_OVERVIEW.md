---
Document ID: PB-401

Document Name: SYSTEM OVERVIEW

Book: Architecture

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

First Brand: SHIK ROLL

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026
---

# SYSTEM OVERVIEW

---

# Purpose

SYSTEM OVERVIEW является высокоуровневым обзором платформы SHIK Platform.

Каноническим техническим обзором архитектуры является ARC-501 SYSTEM OVERVIEW.

Документ описывает:

- общую архитектуру;
- основные приложения;
- взаимодействие сервисов;
- жизненный цикл заказа;
- интеграции;
- облачную инфраструктуру;
- принципы масштабирования.

Детальная реализация каждого модуля описывается в отдельных документах Engineering Handbook.

---

# Platform Vision

SHIK Platform представляет собой независимую облачную платформу автоматизации ресторанного бизнеса.

Первой реализацией платформы является сеть SHIK ROLL.

Архитектура изначально проектируется для масштабирования:

- один ресторан;
- несколько филиалов;
- сеть ресторанов;
- несколько брендов.

---

# High Level Architecture

```text
                              CUSTOMER

                           Mobile Application

                                   │

                          HTTPS / WebSocket

                                   │

                           API Gateway (NestJS)

                                   │

        ┌────────────────────────────────────────────┐
        │                                            │
        │              CORE PLATFORM                 │
        │                                            │
        └────────────────────────────────────────────┘

 Authentication

 Users

 Menu

 Orders

 Loyalty

 Payments

 Kitchen

 Delivery

 Inventory

 Notifications

 Analytics

 Integrations

 Map Provider

                                   │

           ┌───────────────┬───────────────┬───────────────┐

           │               │               │

     PostgreSQL         Redis          BullMQ

           │               │               │

           └───────────────┴───────────────┘

                      Google Cloud Platform
```

---

# Platform Layers

## Layer 1

Core Platform

Ядро системы.

Содержит бизнес-логику.

Не зависит от бренда.

---

## Layer 2

Brand Layer

Содержит:

- логотип
- фирменные цвета
- фотографии
- категории
- рекламные материалы

Для SHIK ROLL.

---

## Layer 3

Configuration Layer

Настройки владельца.

Меняются через Back Office.

Примеры:

- меню
- цены
- акции
- бонусы
- филиалы
- сотрудники
- зоны доставки
- фотографии
- стоп-лист

---

# Applications

Платформа состоит из нескольких приложений.

---

## Customer App

Flutter

Назначение:

Оформление заказов.

Возможности:

- регистрация;
- каталог;
- поиск;
- корзина;
- онлайн-оплата;
- бонусы;
- история заказов;
- отслеживание доставки;
- предзаказ.

---

## Kitchen App

Flutter

Назначение:

Работа кухни.

Возможности:

- новые заказы;
- таймеры;
- техкарты;
- статусы;
- стоп-лист;
- аналитика кухни.

---

## Courier App

Flutter

Назначение:

Работа курьеров.

Возможности:

- навигация;
- маршрут;
- статусы;
- доставка;
- заработок.

---

## POS

Flutter Desktop / Tablet

Назначение:

Работа кассира.

Возможности:

- оформление заказов;
- оплата;
- возвраты;
- чеки;
- смены.

---

## Back Office

Next.js

Назначение:

Управление системой.

Возможности:

- меню;
- категории;
- сотрудники;
- роли;
- акции;
- фотографии;
- филиалы;
- доставка;
- аналитика.

---

## Owner Dashboard

Next.js

Назначение:

Контроль бизнеса.

Возможности:

- KPI;
- прибыль;
- средний чек;
- ABC-анализ;
- сотрудники;
- склады;
- графики.

---

# Backend

Backend является центральной частью платформы.

Все приложения взаимодействуют только через Backend.

Прямое взаимодействие приложений запрещено.

---

# Core Modules

Authentication

Users

Catalog

Orders

Kitchen

Delivery

Inventory

Payments

Notifications

Analytics

HR

Marketing

Integrations

---

# Database

Основная база данных:

PostgreSQL

ORM:

Prisma

Используется:

- транзакции;
- индексы;
- миграции;
- репликация (в будущем).

---

# Cache

Redis

Используется:

- кеш;
- сессии;
- OTP;
- ограничение запросов;
- временные данные.

---

# Queue

BullMQ

Используется:

- push;
- email;
- генерация отчетов;
- экспорт;
- фоновые задачи.

---

# Storage

Google Cloud Storage

Используется для хранения:

- фотографий блюд;
- логотипов;
- баннеров;
- документов;
- файлов импорта.

---

# Notifications

Firebase Cloud Messaging

Используется для:

- клиента;
- кухни;
- курьера;
- владельца.

---

# Maps

Платформа использует собственный Map Provider Layer.

Поддерживаются:

- Google Maps

- Яндекс Карты

- 2GIS

Замена провайдера не требует изменения бизнес-логики.

---

# Payments

Поддерживаются:

- банковские карты;

- СБП;

- наличные;

- смешанная оплата;

- бонусы.

---

# Integrations

Платформа предусматривает интеграции:

- 1С;

- ERP;

- бухгалтерия;

- Telegram;

- Email;

- SMS;

- агрегаторы доставки;

- онлайн-кассы.

---

# AI

Во время разработки используются:

ChatGPT

Claude Code

Claude Design

BMad Method

---

# Security

Основные принципы:

- JWT

- Refresh Tokens

- RBAC

- Audit Log

- 2FA

- HTTPS

- Secret Manager

- Backup

---

# Scalability

Платформа должна поддерживать:

✓ одну точку

✓ несколько точек

✓ сеть ресторанов

✓ несколько брендов

без изменения архитектуры.

---

# Order Lifecycle

Customer

↓

Order

↓

Payment

↓

Backend

↓

Kitchen

↓

Cooking

↓

Ready

↓

Courier / Pickup

↓

Completed

↓

Analytics

---

# Deployment

Google Cloud Platform

Cloud Run

Cloud SQL

Cloud Storage

Cloud Logging

Cloud Monitoring

Artifact Registry

Cloud Build

---

# Future Modules

Планируются:

- AI Recommendations

- AI Analytics

- Smart Kitchen

- Smart Inventory

- Franchise

- BI

- ERP

- CRM

---

# Related Documents

PROJECT_MANIFEST

PROJECT_BIBLE

README

ARC-501 SYSTEM OVERVIEW

Database Book

API Book

Engineering Book

---

# Conclusion

SYSTEM OVERVIEW является высокоуровневым обзором платформы SHIK Platform.

Каноническим техническим обзором архитектуры является ARC-501 SYSTEM OVERVIEW.

Все остальные архитектурные документы являются детализацией данного документа.

END OF DOCUMENT