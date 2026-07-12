---
Document ID: PB-303

Document Name: USER JOURNEYS

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

# USER JOURNEYS

## Purpose

Данный документ описывает ключевые пользовательские сценарии (User Journeys), которые определяют взаимодействие пользователей с SHIK Platform.

Каждый сценарий используется при проектировании:

- экранов;
- API;
- базы данных;
- тестов;
- аналитики;
- бизнес-логики.

---

# Journey Overview

| ID | Journey | Persona | Priority |
|----|----------|----------|----------|
| UJ-001 | Customer Registration | Customer | Must |
| UJ-002 | Customer Login | Customer | Must |
| UJ-003 | Browse Menu | Customer | Must |
| UJ-004 | Product Details | Customer | Must |
| UJ-005 | Add to Cart | Customer | Must |
| UJ-006 | Checkout | Customer | Must |
| UJ-007 | Online Payment | Customer | Must |
| UJ-008 | Pickup Order | Customer | Must |
| UJ-009 | Delivery Order | Customer | Must |
| UJ-010 | Track Order | Customer | Must |
| UJ-011 | Repeat Order | Customer | Should |
| UJ-012 | Loyalty Program | Customer | Should |

---

# UJ-001 Customer Registration

## Goal

Создать личный кабинет клиента.

## Actor

Customer

## Trigger

Пользователь открывает приложение впервые.

## Main Flow

1. Открыть приложение.
2. Выбрать регистрацию.
3. Указать телефон или email.
4. Подтвердить код.
5. Заполнить профиль.
6. Получить доступ к приложению.

## Success Result

Аккаунт создан.

## Acceptance Criteria

- регистрация занимает менее 2 минут;
- подтверждение выполняется успешно;
- пользователь автоматически входит в систему.

---

# UJ-003 Browse Menu

## Goal

Просмотреть актуальное меню ресторана.

## Actor

Customer

## Main Flow

1. Открыть меню.
2. Выбрать категорию.
3. Просмотреть блюда.
4. Открыть карточку блюда.

## Success Result

Пользователь находит нужное блюдо.

## Acceptance Criteria

- меню загружается быстро;
- отображаются фотографии;
- отображается актуальная цена;
- отображается статус доступности.

---

# UJ-006 Checkout

## Goal

Оформить заказ.

## Main Flow

1. Проверить корзину.
2. Выбрать способ получения.
3. Выбрать способ оплаты.
4. Подтвердить заказ.
5. Получить номер заказа.

## Success Result

Заказ успешно создан.

## Acceptance Criteria

- заказ сохраняется;
- клиент получает уведомление;
- заказ появляется на кухне.

---

# UJ-010 Track Order

## Goal

Следить за выполнением заказа.

## Main Flow

1. Открыть заказ.
2. Просмотреть текущий статус.
3. Получать уведомления об изменениях.

## Statuses

- Created
- Confirmed
- Preparing
- Ready
- On the Way
- Completed

## Success Result

Клиент всегда знает актуальный статус.

---

# Journey Principles

Каждый пользовательский сценарий должен:

- состоять из минимального количества действий;
- иметь понятную навигацию;
- завершаться измеримым результатом;
- содержать критерии приемки (Acceptance Criteria).

---

# Traceability

Каждый Journey должен быть связан с:

- Business Requirement (BR);
- Functional Requirement (FR);
- User Story (US);
- Screen (SCR);
- API;
- Database;
- Test Case.

---

# AI Context

Все новые пользовательские сценарии должны оформляться по структуре данного документа.

Новый сценарий не может быть реализован без определения:

- цели;
- акторов;
- основного потока;
- критериев приемки;
- связей с RTM.

---

# Related Documents

PB-300 PRODUCT_PRINCIPLES

PB-301 PRODUCT_OVERVIEW

PB-302 USER_PERSONAS

PB-304 BUSINESS_CAPABILITIES

PB-305 PRODUCT_REQUIREMENTS

END OF DOCUMENT