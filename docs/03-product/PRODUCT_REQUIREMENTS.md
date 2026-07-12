---
Document ID: PB-305

Document Name: PRODUCT REQUIREMENTS

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

# PRODUCT REQUIREMENTS

## Purpose

Данный документ содержит полный каталог функциональных (FR) и нефункциональных (NFR) требований SHIK Platform.

Каждое требование имеет:

- уникальный идентификатор;
- описание;
- бизнес-ценность;
- приоритет;
- критерии приемки (Acceptance Criteria);
- связи с RTM.

---

# Priority Model

Используется модель MoSCoW.

| Priority | Description |
|----------|-------------|
| Must | Обязательно для MVP |
| Should | Желательно |
| Could | Может быть реализовано позже |
| Won't | Не входит в текущую версию |

---

# Functional Requirements

## FR-001 Customer Registration

### Description

Пользователь должен иметь возможность зарегистрироваться по номеру телефона или адресу электронной почты.

### Priority

Must

### Business Value

Создание учетной записи клиента.

### Acceptance Criteria

- регистрация завершается менее чем за 2 минуты;
- подтверждение происходит через OTP;
- создается профиль клиента;
- пользователь автоматически входит в систему после успешной регистрации.

### Related

BR-001

PR-001

UJ-001

SCR-CUS-001

API-AUTH-001

TEST-FR-001

---

## FR-002 Customer Authentication

### Description

Пользователь должен иметь возможность авторизоваться.

### Supported Methods

- Phone
- Email
- Google
- Apple

### Priority

Must

### Acceptance Criteria

- вход занимает менее 30 секунд;
- создается безопасная пользовательская сессия;
- поддерживается обновление токенов.

### Related

BR-001

PR-001

UJ-002

SCR-CUS-002

API-AUTH-002

TEST-FR-002

---

## FR-003 Browse Menu

### Description

Пользователь может просматривать актуальное меню.

### Acceptance Criteria

- отображаются категории;
- отображаются фотографии;
- отображаются цены;
- отображается халяльная маркировка;
- отображается информация о наличии блюда;
- изменения из Back Office отображаются без публикации новой версии приложения.

### Priority

Must

### Related

BR-002

PR-003

UJ-003

SCR-CUS-010

API-MENU-001

TEST-FR-003

---

## FR-004 Product Details

### Description

Пользователь может открыть карточку блюда.

### Acceptance Criteria

Карточка содержит:

- фотографии;
- описание;
- состав;
- аллергены;
- халяльную маркировку;
- модификаторы;
- пищевую ценность (опционально);
- цену;
- рекомендации.

### Priority

Must

### Related

BR-002

PR-003

UJ-004

SCR-CUS-011

API-MENU-002

TEST-FR-004

---

## FR-005 Add To Cart

### Description

Пользователь может добавить товар в корзину.

### Acceptance Criteria

- поддерживается изменение количества;
- поддерживаются модификаторы;
- пересчитывается итоговая стоимость;
- изменения происходят без перезагрузки экрана.

### Priority

Must

### Related

BR-002

PR-004

UJ-005

SCR-CUS-020

API-CART-001

TEST-FR-005
---

## FR-006 Checkout

### Description

Пользователь должен иметь возможность оформить заказ после формирования корзины.

### Priority

Must

### Business Value

Обеспечить быстрый и понятный процесс оформления заказа.

### Acceptance Criteria

- отображается итоговая стоимость;
- отображается стоимость доставки (если применимо);
- отображается предполагаемое время приготовления;
- пользователь выбирает способ получения;
- пользователь выбирает способ оплаты;
- пользователь подтверждает заказ одной кнопкой.

### Related

BR-003

PR-005

UJ-006

SCR-CUS-030

API-ORDER-001

TEST-FR-006

---

## FR-007 Online Payments

### Description

Платформа должна поддерживать несколько способов оплаты.

### Supported Payment Methods

- Банковская карта
- СБП
- Apple Pay
- Google Pay
- Наличные
- Оплата при получении
- Смешанная оплата (бонусы + деньги)

### Priority

Must

### Acceptance Criteria

- пользователь видит только доступные способы оплаты;
- платеж подтверждается менее чем за 10 секунд;
- при ошибке пользователь получает понятное сообщение;
- создается запись о платеже;
- поддерживается повторная попытка оплаты.

### Related

BR-003

PR-006

UJ-007

SCR-CUS-031

API-PAY-001

TEST-FR-007

---

## FR-008 Order Management

### Description

Система должна сопровождать заказ на всех этапах жизненного цикла.

### Supported Statuses

- Draft
- Created
- Confirmed
- Preparing
- Ready
- Courier Assigned
- On Delivery
- Ready For Pickup
- Completed
- Cancelled
- Refunded

### Priority

Must

### Acceptance Criteria

- каждый статус фиксируется;
- статус синхронизируется между всеми приложениями;
- изменение статуса записывается в Audit Log;
- клиент получает соответствующее уведомление.

### Related

BR-004

PR-007

UJ-010

API-ORDER-002

TEST-FR-008

---

## FR-009 Delivery Management

### Description

Платформа должна поддерживать собственную доставку ресторана.

### Functional Scope

- зоны доставки;
- стоимость доставки;
- назначение курьера;
- отслеживание заказа;
- расчет ETA;
- завершение доставки.

### Priority

Must

### Acceptance Criteria

- адрес проходит валидацию;
- стоимость доставки рассчитывается автоматически;
- курьер получает маршрут;
- клиент видит движение заказа.

### Related

BR-005

PR-008

UJ-009

API-DELIVERY-001

TEST-FR-009

---

## FR-010 Pickup Management

### Description

Пользователь должен иметь возможность оформить самовывоз.

### Acceptance Criteria

- пользователь выбирает филиал;
- отображается ориентировочное время готовности;
- заказ отображается в очереди кухни;
- клиент получает уведомление "Готов к выдаче".

### Priority

Must

### Related

BR-005

PR-009

UJ-008

API-PICKUP-001

TEST-FR-010

---

## FR-011 Communication Automation Center

### Description

Communication Automation Center управляет всеми коммуникациями платформы.

### Supported Channels

- Push Notifications
- In-App
- WhatsApp Business
- Telegram
- Email
- SMS
- Webhooks

### Functional Scope

- правила отправки;
- шаблоны сообщений;
- настройки филиалов;
- предпочтения клиента;
- журнал доставки;
- тихие часы;
- резервные каналы (Phase 2).

### Priority

Must

### Acceptance Criteria

- владелец может изменять правила без участия разработчика;
- изменение правил не требует публикации новой версии приложения;
- сообщения журналируются;
- шаблоны поддерживают переменные;
- клиент может отказаться от маркетинговых сообщений.

### Related

BR-006

PR-010

PB-306

API-COM-001

TEST-FR-011

---

## FR-012 Loyalty Program

### Description

Платформа должна поддерживать встроенную программу лояльности.

### Functional Scope

- бонусные баллы;
- уровни клиентов;
- кэшбэк;
- персональные предложения;
- промокоды;
- купоны;
- подарочные сертификаты (Phase 2).

### Priority

Should

### Acceptance Criteria

- бонусы начисляются автоматически;
- бонусы можно списывать согласно правилам;
- история операций доступна клиенту;
- владелец управляет правилами начисления через Back Office.

### Related

BR-007

PR-011

UJ-012

API-LOYALTY-001

TEST-FR-012