---
Document ID: PB-302

Document Name: USER PERSONAS

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

# USER PERSONAS

## Purpose

Данный документ определяет основные категории пользователей SHIK Platform.

Каждая персона используется при проектировании:

- пользовательских сценариев;
- интерфейсов;
- бизнес-логики;
- API;
- уведомлений;
- тестирования.

---

# Persona Overview

Платформа обслуживает восемь основных типов пользователей.

| ID | Persona | Основное приложение |
|----|----------|---------------------|
| PER-001 | Customer | Customer App |
| PER-002 | Cashier | POS |
| PER-003 | Kitchen Staff | Kitchen App |
| PER-004 | Courier | Courier App |
| PER-005 | Restaurant Manager | Back Office |
| PER-006 | Owner | Owner Dashboard |
| PER-007 | System Administrator | Platform |
| PER-008 | Support Engineer | Platform |

---

# PER-001 Customer

## Description

Гость ресторана SHIK ROLL.

Основной пользователь платформы.

---

## Goals

- Быстро оформить заказ.
- Легко найти нужное блюдо.
- Получить качественную еду.
- Оплатить удобным способом.
- Следить за статусом заказа.
- Получать бонусы.

---

## Pain Points

- Долгое ожидание.
- Сложное меню.
- Непонятный статус заказа.
- Медленная работа приложения.

---

## Digital Experience

Высокая.

Пользователь ежедневно использует мобильные приложения.

---

## Main Scenarios

- Заказ доставки.
- Самовывоз.
- Предзаказ.
- Повтор заказа.
- Использование бонусов.

---

## Uses

- Customer App

---

# PER-002 Cashier

## Description

Сотрудник кассы.

---

## Goals

- Быстро обслужить гостя.
- Минимизировать ошибки.
- Быстро оформить оплату.

---

## Pain Points

- Очереди.
- Ошибки при вводе заказа.
- Медленная работа кассы.

---

## Uses

- POS

---

# PER-003 Kitchen Staff

## Description

Повар.

---

## Goals

- Быстро видеть новые заказы.
- Не пропускать комментарии.
- Контролировать время приготовления.

---

## Pain Points

- Потерянные заказы.
- Непонятные комментарии.
- Отсутствие информации о стоп-листе.

---

## Uses

- Kitchen App

---

# PER-004 Courier

## Description

Курьер ресторана.

---

## Goals

- Получить маршрут.
- Быстро доставить заказ.
- Обновить статус.

---

## Pain Points

- Неточная навигация.
- Долгое ожидание готовности.
- Ошибки в адресе.

---

## Uses

- Courier App

---

# PER-005 Restaurant Manager

## Description

Управляющий рестораном.

---

## Goals

- Управлять персоналом.
- Контролировать меню.
- Управлять акциями.
- Следить за показателями.

---

## Pain Points

- Большое количество ручной работы.
- Отсутствие актуальной аналитики.
- Медленное обновление информации.

---

## Uses

- Back Office

---

# PER-006 Owner

## Description

Владелец бизнеса.

---

## Goals

- Контроль прибыли.
- Управление сетью ресторанов.
- Анализ KPI.
- Масштабирование бизнеса.

---

## Pain Points

- Разрозненные системы.
- Недостаток аналитики.
- Зависимость от сторонних сервисов.

---

## Uses

- Owner Dashboard

---

# PER-007 System Administrator

## Description

Администратор платформы.

---

## Goals

- Обеспечить стабильность системы.
- Контролировать инфраструктуру.
- Управлять пользователями.

---

## Uses

- Platform Administration

---

# PER-008 Support Engineer

## Description

Специалист технической поддержки.

---

## Goals

- Быстро находить причины ошибок.
- Помогать пользователям.
- Работать с журналами событий.

---

## Uses

- Support Console

---

# Design Implications

При проектировании интерфейсов необходимо учитывать:

- минимальное количество действий;
- понятные названия;
- единое расположение элементов;
- высокую скорость работы;
- поддержку мобильных устройств.

---

# AI Context

Каждая новая функция должна быть связана минимум с одной пользовательской персоной.

Если невозможно определить, для кого создается функция, необходимость ее реализации должна быть пересмотрена.

---

# Related Documents

PB-300 PRODUCT_PRINCIPLES

PB-301 PRODUCT_OVERVIEW

PB-303 USER_JOURNEYS

PB-304 BUSINESS_CAPABILITIES

PB-305 PRODUCT_REQUIREMENTS

PB-106 STAKEHOLDERS

END OF DOCUMENT