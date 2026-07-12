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