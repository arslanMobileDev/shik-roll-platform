---
Document ID: PB-301

Document Name: PRODUCT OVERVIEW

Book: Product

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Product Category: Cloud-native Restaurant Operating System (Restaurant OS)

First Brand: SHIK ROLL

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# PRODUCT OVERVIEW

## Purpose

Данный документ описывает SHIK Platform как единый цифровой продукт и определяет состав платформы, взаимосвязь модулей, область ответственности каждого приложения и принципы взаимодействия между ними.

Этот документ является отправной точкой для проектирования всех пользовательских интерфейсов, API и бизнес-процессов.

---

# Product Definition

SHIK Platform — это облачная Restaurant Operating System, объединяющая все процессы ресторана в единой цифровой экосистеме.

Платформа охватывает весь жизненный цикл работы ресторана:

- привлечение клиента;
- оформление заказа;
- приготовление;
- выдача или доставка;
- управление персоналом;
- аналитика;
- финансовый контроль;
- масштабирование сети ресторанов.

---

# Product Scope

В первую версию платформы входят следующие приложения.

## Customer Mobile App

Назначение:

Приложение для гостей ресторана.

Основные возможности:

- регистрация;
- просмотр меню;
- оформление заказа;
- онлайн-оплата;
- предзаказ;
- доставка;
- самовывоз;
- бонусная программа;
- отслеживание заказа.

---

## Kitchen App

Назначение:

Рабочее место кухни.

Основные возможности:

- очередь заказов;
- статусы приготовления;
- комментарии;
- техкарты;
- стоп-лист;
- контроль времени.

---

## Courier App

Назначение:

Рабочее место курьера.

Основные возможности:

- получение заказов;
- маршруты;
- изменение статусов;
- история доставок.

---

## POS

Назначение:

Рабочее место кассира.

Основные возможности:

- оформление заказа;
- прием оплаты;
- возвраты;
- смены;
- печать чеков.

---

## Back Office

Назначение:

Центральная система управления рестораном.

Основные возможности:

- управление меню;
- управление филиалами;
- управление сотрудниками;
- склад;
- акции;
- бонусы;
- настройки платформы.

---

## Owner Dashboard

Назначение:

Стратегическое управление бизнесом.

Основные возможности:

- финансовая аналитика;
- KPI;
- отчеты;
- показатели филиалов;
- эффективность персонала;
- прогнозирование.

---

# Product Architecture

Все приложения работают через единый Backend.

```text
Customer App
Kitchen App
Courier App
POS
Back Office
Owner Dashboard
        │
        ▼
Backend API
        │
        ▼
Business Services
        │
        ▼
Database
```

---

# Supported Platforms

## Mobile

- iOS
- Android

---

## Web

- Back Office
- Dashboard
- QR Menu

---

## Future

- Self-Service Kiosk
- Smart TV Menu Boards
- Desktop POS
- Apple Watch (уведомления)
- Wear OS

---

# Core Modules

Платформа состоит из независимых модулей.

- Authentication
- Users
- Restaurants
- Branches
- Menu
- Products
- Media
- Orders
- Kitchen
- Delivery
- Inventory
- Loyalty
- Promotions
- Payments
- Notifications
- Analytics
- Reports
- Settings

---

# Maps

Поддерживаются следующие картографические сервисы:

- Google Maps
- Яндекс Карты
- 2GIS

Выбор осуществляется в настройках платформы.

---

# Media

Все фотографии блюд управляются через Back Office.

После публикации фотография автоматически становится доступной:

- Customer App;
- POS;
- Kitchen;
- QR Menu;
- Menu Boards;
- Owner Dashboard.

---

# Brand

Первая реализация платформы предназначена для бренда SHIK ROLL.

Особенности бренда:

- Halal Fast Food;
- современный цифровой сервис;
- быстрое обслуживание;
- качественные фотографии блюд;
- единый фирменный стиль.

---

# Product Principles

При проектировании каждого нового модуля соблюдаются следующие принципы.

- Configuration First
- API First
- Mobile First
- Cloud Native
- Security by Design
- Modular Architecture
- Vendor Independence
- AI Assisted Development

---

# Out of Scope (MVP)

В первую версию продукта не входят:

- франчайзинговый кабинет;
- ERP;
- CRM;
- Marketplace модулей;
- AI-прогнозирование продаж;
- компьютерное зрение;
- голосовое управление.

Архитектура должна предусматривать возможность их добавления без изменения существующих модулей.

---

# Success Criteria

Первая версия продукта считается успешной, если:

- ресторан SHIK ROLL полностью работает на собственной платформе;
- владелец управляет системой через Back Office и Owner Dashboard;
- сотрудники используют только SHIK Platform;
- изменения меню выполняются без участия разработчика;
- подключение нового филиала выполняется через настройки.

---

# AI Context

Этот документ является центральной точкой Product Book.

Все последующие документы должны соответствовать структуре и принципам, определенным здесь.

---

# Related Documents

PB-300 PRODUCT_PRINCIPLES

PB-302 USER_PERSONAS

PB-303 USER_JOURNEYS

PB-304 BUSINESS_CAPABILITIES

PB-305 PRODUCT_REQUIREMENTS

PB-401 SYSTEM_OVERVIEW

END OF DOCUMENT