---
Document ID: PB-304

Document Name: BUSINESS CAPABILITIES

Book: Product

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Product Category: Cloud-native Restaurant Operating System (Restaurant OS)

First Brand: SHIK ROLL

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Standard: IEEE 29148 (Adapted)

Last Updated: July 2026

Classification: Internal
---

# BUSINESS CAPABILITIES

## Purpose

Данный документ определяет полный перечень возможностей (Business Capabilities), которые предоставляет SHIK Platform.

Business Capability — это способность платформы выполнять определенную бизнес-функцию независимо от того, как именно она реализована технически.

Каждая возможность в дальнейшем будет детализирована в Product Specification, API, Database и тестах.

---

# Capability Map

SHIK Platform состоит из следующих крупных доменов.

| ID | Capability | Priority |
|----|------------|----------|
| CAP-001 | Customer Management | Must |
| CAP-002 | Authentication | Must |
| CAP-003 | Restaurant Management | Must |
| CAP-004 | Branch Management | Must |
| CAP-005 | Menu Management | Must |
| CAP-006 | Product Management | Must |
| CAP-007 | Media Management | Must |
| CAP-008 | Order Management | Must |
| CAP-009 | Kitchen Operations | Must |
| CAP-010 | Delivery Management | Must |
| CAP-011 | Pickup Management | Must |
| CAP-012 | POS Operations | Must |
| CAP-013 | Payment Processing | Must |
| CAP-014 | Loyalty Program | Should |
| CAP-015 | Promotions | Should |
| CAP-016 | Inventory Management | Must |
| CAP-017 | Employee Management | Must |
| CAP-018 | Analytics | Must |
| CAP-019 | Notifications | Must |
| CAP-020 | Reporting | Should |
| CAP-021 | Configuration | Must |
| CAP-022 | Security | Must |
| CAP-023 | Audit Log | Must |
| CAP-024 | Integrations | Should |
| CAP-025 | AI Services | Could |

---

# CAP-001 Customer Management

## Business Value

Управление клиентами ресторана.

### Includes

- регистрация;
- профиль;
- адреса;
- история заказов;
- бонусы;
- избранное.

---

# CAP-005 Menu Management

## Business Value

Полностью управляемое меню без участия разработчика.

### Includes

- категории;
- блюда;
- фотографии;
- цены;
- модификаторы;
- стоп-лист;
- сезонные предложения;
- халяльная маркировка;
- рекомендации.

---

# CAP-008 Order Management

## Business Value

Полный жизненный цикл заказа.

### Includes

- создание;
- изменение;
- подтверждение;
- оплата;
- приготовление;
- доставка;
- завершение;
- отмена;
- возврат.

---

# CAP-009 Kitchen Operations

## Business Value

Автоматизация кухни.

### Includes

- очередь заказов;
- статусы;
- техкарты;
- таймеры;
- комментарии;
- контроль времени;
- аналитика кухни.

---

# CAP-010 Delivery Management

## Business Value

Управление собственной доставкой.

### Includes

- назначение курьера;
- маршруты;
- зоны доставки;
- стоимость доставки;
- статусы;
- трекинг.

---

# CAP-012 POS Operations

## Business Value

Современная кассовая система.

### Includes

- продажи;
- возвраты;
- смены;
- печать чеков;
- дисплей покупателя.

---

# CAP-014 Loyalty Program

## Business Value

Повышение повторных продаж.

### Includes

- бонусы;
- кэшбэк;
- персональные предложения;
- уровни лояльности.

---

# CAP-016 Inventory Management

## Business Value

Контроль складских остатков.

### Includes

- остатки;
- списания;
- инвентаризация;
- автоматический стоп-лист;
- уведомления.

---

# CAP-018 Analytics

## Business Value

Принятие решений на основе данных.

### Includes

- продажи;
- прибыль;
- популярные блюда;
- эффективность сотрудников;
- загрузка кухни;
- показатели филиалов.

---

# CAP-019 Notifications

## Business Value

Единый центр уведомлений.

### Channels

- Push;
- Email;
- Telegram;
- SMS;
- In-App.

---

# CAP-021 Configuration

## Business Value

Настройка платформы без изменения кода.

### Includes

- филиалы;
- карты;
- способы оплаты;
- зоны доставки;
- рабочие часы;
- бренд;
- социальные сети;
- настройки AI.

---

# CAP-022 Security

## Business Value

Защита данных и операций.

### Includes

- RBAC;
- 2FA;
- аудит;
- журнал действий;
- управление сессиями.

---

# CAP-024 Integrations

## Business Value

Подключение внешних сервисов.

### Includes

- Google Maps;
- Яндекс Карты;
- 2GIS;
- платежные системы;
- SMS;
- Email;
- Telegram;
- 1С;
- ERP;
- агрегаторы доставки.

---

# CAP-025 AI Services

## Business Value

Использование искусственного интеллекта для развития платформы.

### Includes

- аналитика;
- рекомендации;
- генерация отчетов;
- помощь в управлении;
- AI-помощник владельца (будущая версия).

---

# Capability Principles

Каждая возможность должна:

- приносить бизнес-ценность;
- быть независимой;
- поддерживать масштабирование;
- иметь API;
- иметь тесты;
- иметь документацию.

---

# Traceability

Каждая Capability должна быть связана с:

- BR;
- PR;
- FR;
- User Stories;
- User Journeys;
- Screens;
- API;
- Database;
- Tests.

---

# AI Context

Все новые функции платформы должны относиться минимум к одной Business Capability.

Если новая функция не попадает ни в одну Capability, необходимо либо создать новую Capability, либо пересмотреть необходимость реализации функции.

---

# Related Documents

PB-300 PRODUCT_PRINCIPLES

PB-301 PRODUCT_OVERVIEW

PB-302 USER_PERSONAS

PB-303 USER_JOURNEYS

PB-305 PRODUCT_REQUIREMENTS

RTM-001 REQUIREMENTS_TRACEABILITY_MATRIX

END OF DOCUMENT