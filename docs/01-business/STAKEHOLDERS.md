---
Document ID: PB-106

Document Name: STAKEHOLDERS

Book: Business

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

# STAKEHOLDERS

## Purpose

Данный документ определяет всех участников экосистемы SHIK Platform, их роли, цели, ответственность и права доступа.

Этот документ является основой для:

- RBAC (Role Based Access Control)
- UI/UX
- API Authorization
- Database Permissions
- Audit Log
- Business Rules

---

# Stakeholder Overview

Экосистема SHIK Platform включает несколько групп пользователей.

| Роль | Основная задача |
|-------|-----------------|
| Customer | Заказ продукции |
| Cashier | Продажа и прием оплаты |
| Kitchen Staff | Приготовление заказов |
| Courier | Доставка заказов |
| Manager | Управление рестораном |
| Owner | Управление бизнесом |
| System Administrator | Управление платформой |
| Support Engineer | Техническая поддержка |

---

# Customer

## Description

Гость ресторана.

Использует мобильное приложение.

---

## Goals

- Быстро оформить заказ.
- Получить качественный сервис.
- Получить бонусы.
- Повторить заказ.
- Отслеживать статус.

---

## Main Functions

- Регистрация.
- Авторизация.
- Просмотр меню.
- Корзина.
- Оплата.
- История заказов.
- Предзаказ.
- Доставка.
- Самовывоз.

---

## Permissions

Доступ только к собственным данным.

---

# Cashier

## Description

Работник кассы.

---

## Goals

- Быстро оформить заказ.
- Принять оплату.
- Напечатать чек.
- Закрыть смену.

---

## Main Functions

- Создание заказа.
- Изменение заказа.
- Возврат.
- Печать чека.
- Работа со сменой.

---

## Permissions

Работа только в пределах своей точки продаж.

---

# Kitchen Staff

## Description

Повар или сотрудник кухни.

---

## Goals

- Получать новые заказы.
- Выполнять их вовремя.
- Менять статус приготовления.

---

## Main Functions

- Просмотр заказов.
- Таймер приготовления.
- Просмотр комментариев.
- Работа с техкартами.
- Работа со стоп-листом.
- Отметка готовности.

---

## Permissions

Нет доступа к финансам.

---

# Courier

## Description

Курьер ресторана.

---

## Goals

- Быстро доставить заказ.
- Обновлять статусы.

---

## Main Functions

- Получение маршрута.
- Навигация.
- Подтверждение доставки.
- История заказов.

---

## Permissions

Доступ только к назначенным заказам.

---

# Manager

## Description

Управляющий рестораном.

---

## Goals

- Управление рестораном.
- Контроль сотрудников.
- Контроль меню.
- Управление акциями.

---

## Main Functions

- Управление меню.
- Управление ценами.
- Управление сотрудниками.
- Управление филиалом.
- Просмотр отчетов.

---

## Permissions

Полный доступ в пределах ресторана.

---

# Owner

## Description

Владелец бизнеса.

---

## Goals

- Контроль сети ресторанов.
- Аналитика.
- Прибыль.
- Развитие бизнеса.

---

## Main Functions

- Dashboard.
- KPI.
- Финансовая аналитика.
- Управление филиалами.
- Управление брендом.

---

## Permissions

Максимальный уровень доступа.

---

# System Administrator

## Description

Администратор платформы.

---

## Goals

- Обеспечение стабильной работы системы.
- Управление настройками платформы.

---

## Main Functions

- Управление пользователями.
- Управление ролями.
- Мониторинг.
- Логи.
- Инфраструктура.

---

## Permissions

Полный технический доступ.

---

# Support Engineer

## Description

Специалист технической поддержки.

---

## Goals

- Помощь пользователям.
- Диагностика проблем.

---

## Main Functions

- Просмотр логов.
- Анализ ошибок.
- Работа с обращениями.

---

## Permissions

Ограниченный технический доступ без изменения бизнес-данных.

---

# Role Hierarchy

```text
Owner
│
├── Manager
│   ├── Cashier
│   ├── Kitchen Staff
│   └── Courier
│
├── System Administrator
│
└── Support Engineer

Customer
```

---

# Access Principles

Все пользователи получают только минимально необходимый уровень доступа.

Используется принцип **Least Privilege**.

Каждое действие фиксируется в **Audit Log**.

---

# Authentication

Поддерживаемые способы входа:

- Email
- Google
- Apple
- Phone Number

Для сотрудников:

- Email
- PIN (POS)
- QR Login (в перспективе)

---

# Authorization

Используется **Role-Based Access Control (RBAC)**.

Каждая роль имеет собственный набор разрешений.

Права определяются централизованно.

---

# AI Context

Все новые функции должны учитывать роли пользователей.

Запрещается создавать функциональность без определения:

- владельца функции;
- уровня доступа;
- сценария использования.

---

# Related Documents

PB-101 BUSINESS_VISION

PB-102 PRODUCT_VISION

PB-103 MISSION

PB-104 BUSINESS_GOALS

PB-105 BUSINESS_MODEL

PB-107 SUCCESS_METRICS

PB-401 SYSTEM_OVERVIEW

END OF DOCUMENT