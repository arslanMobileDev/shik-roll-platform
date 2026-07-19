---
Document ID: UI-803

Document Name: COMPONENT LIBRARY

Book: Frontend Specification

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Design Authority: Claude Design

Last Updated: July 2026

Classification: Internal
---

# COMPONENT LIBRARY

## Purpose

Определяет единую библиотеку повторно используемых Flutter-компонентов для приложений SHIK Platform.

Библиотека реализует визуальные основы UI-802 Design System и предоставляет согласованные компоненты для мобильных, web, POS, KDS и dashboard-интерфейсов.

---

# Goals

- единое поведение интерфейсов;
- повторное использование компонентов;
- снижение дублирования;
- согласованная доступность;
- предсказуемая адаптивность;
- контролируемое развитие публичного API компонентов;
- единая связь между дизайном, реализацией и тестами.

---

# Document Boundary

UI-802 Design System определяет:

- design tokens;
- цвета;
- типографику;
- spacing;
- grids and breakpoints;
- themes;
- motion;
- accessibility principles;
- naming conventions.

UI-803 Component Library определяет:

- реализуемые Flutter-компоненты;
- варианты и состояния;
- публичные параметры компонентов;
- правила композиции;
- требования к тестированию;
- управление версиями и изменениями.

Экранные сценарии и UX отдельных приложений определяются документами UI-804–UI-810.

---

# Principles

- Reusable
- Composable
- Accessible
- Theme-Aware
- Localization-Ready
- Responsive
- Testable
- Backward-Compatible by Default
- Business-Logic Independent

---

# Component Layers

## Foundations

- Theme Access
- Design Token Access
- Typography Styles
- Spacing Utilities
- Responsive Breakpoints
- Icon Access

## Primitives

- Text
- Icon
- Divider
- Surface
- Container
- Spacer
- Image

## Controls

- Button
- Icon Button
- Text Field
- Search Field
- Checkbox
- Radio
- Switch
- Slider
- Segmented Control
- Dropdown

## Navigation

- App Bar
- Bottom Navigation
- Navigation Rail
- Drawer
- Tabs
- Breadcrumbs
- Pagination

## Feedback

- Alert
- Banner
- Snackbar
- Dialog
- Bottom Sheet
- Tooltip
- Progress Indicator
- Skeleton
- Empty State
- Error State

## Data Display

- Card
- List Item
- Badge
- Chip
- Avatar
- Table
- Data Grid
- Key Value Row
- Status Indicator

## Commerce and Operations

- Product Card
- Price Display
- Quantity Selector
- Cart Item
- Order Status
- Order Timeline
- Payment Status
- Kitchen Ticket
- Delivery Status
- Catalog Status Badge
- Product Media Gallery
- Product Media Uploader
- Category Sortable List
- Product Sortable List
- Catalog Import Panel
- Import Validation Summary
- Catalog Preview Banner
- Publish Confirmation Dialog
- Branch Availability Control
- Stop List Control

Catalog components must remain business-logic independent. Status transitions, import processing, publication and storage operations are supplied through typed callbacks and state models.

---

# Component Contract

Каждый компонент должен определять:

- purpose;
- supported variants;
- supported states;
- required and optional parameters;
- emitted events;
- accessibility behavior;
- responsive behavior;
- localization behavior;
- error and loading behavior;
- usage examples;
- unsupported use cases.

Компоненты не должны содержать бизнес-правила конкретного приложения.

---

# States

Компоненты должны поддерживать применимые состояния:

- Default
- Hover
- Focus
- Pressed
- Selected
- Disabled
- Loading
- Empty
- Error
- Success

Состояния должны соответствовать UI-802 Design System и быть проверяемыми независимо от конкретного экрана.

---

# Variants

Варианты допускаются только при наличии различимого назначения.

Примеры:

- Primary
- Secondary
- Tertiary
- Destructive
- Compact
- Standard
- Expanded

Новый вариант не должен создаваться только для одного экрана, если задачу можно решить композицией существующих компонентов.

---

# Flutter Requirements

- компоненты реализуются как повторно используемые Flutter widgets;
- Flutter и Flutter Web используют общий компонентный контракт;
- платформенные различия инкапсулируются внутри компонента или адаптера;
- публичный API должен быть типизирован;
- компоненты получают значения оформления через UI-802 tokens and themes;
- запрещено напрямую встраивать секреты, сетевые вызовы или бизнес-логику;
- компоненты должны поддерживать dependency injection там, где требуется внешнее поведение.

---

# Accessibility

Каждый интерактивный компонент должен обеспечивать:

- semantic labels;
- keyboard navigation для web и desktop;
- предсказуемый focus order;
- visible focus state;
- minimum touch target 44×44;
- поддержку screen reader;
- достаточный contrast;
- поддержку масштабирования текста;
- отсутствие зависимости только от цвета.

---

# Localization

Компоненты должны:

- принимать локализованный текст извне;
- поддерживать изменение длины текста;
- учитывать направление текста;
- использовать локализованные форматы даты, времени, числа и валюты;
- не содержать пользовательские строки, зашитые в компонент.

---

# Responsive Behavior

Компоненты должны определять поведение для:

- Mobile
- Tablet
- Desktop
- Large Desktop

Адаптация может включать:

- изменение размера;
- изменение плотности;
- смену навигационного паттерна;
- перенос содержимого;
- переход от списка к таблице;
- изменение расположения действий.

---

# Testing Requirements

Для каждого компонента применяются:

- unit tests для логики состояния;
- widget tests;
- accessibility checks;
- visual regression tests для ключевых вариантов;
- responsive tests;
- theme tests;
- localization tests;
- interaction tests.

Catalog components additionally require tests for:

- Draft, Published, Hidden and Stop List states;
- empty, uploading, processing, failed and completed media states;
- partial import validation results;
- keyboard-accessible ordering;
- destructive confirmation flows;
- long product names, missing images and variable price formats.

Критические компоненты заказа, оплаты, кухни и доставки должны иметь тесты всех поддерживаемых состояний.

---

# Definition of Ready

Компонент готов к реализации, когда определены:

- назначение;
- дизайн;
- variants;
- states;
- public API;
- accessibility requirements;
- responsive behavior;
- acceptance criteria.

---

# Definition of Done

Компонент считается готовым, когда:

- использует UI-802 tokens;
- реализованы утвержденные variants and states;
- пройдены обязательные тесты;
- проверена доступность;
- добавлены примеры использования;
- определено поведение ошибок и загрузки;
- выполнен design review;
- изменение отражено в changelog библиотеки.

---

# Change Management

Изменения классифицируются как:

- Patch — исправление без изменения публичного контракта;
- Minor — обратно совместимый новый вариант или возможность;
- Major — несовместимое изменение публичного API или поведения.

Несовместимые изменения требуют:

- описания миграции;
- оценки затрагиваемых приложений;
- согласования с владельцами UI-документов;
- обновления примеров и тестов.

---

# Ownership

Design Authority отвечает за:

- визуальную согласованность;
- соответствие UI-802;
- утверждение вариантов и состояний.

Frontend Engineering отвечает за:

- публичный API;
- качество реализации;
- тестирование;
- совместимость;
- публикацию изменений.

Product Owners отвечают за требования конкретных экранов и сценариев, но не создают отдельные базовые компоненты без review библиотеки.

---

# Related Documents

UI-801 Frontend Overview

UI-802 Design System

UI-804 Customer Mobile App UX

UI-805 Back Office UX

UI-806 POS UX

UI-807 Kitchen Display System UX

UI-808 Courier Mobile App UX

UI-809 Owner Dashboard UX

UI-810 Design Handoff Specification

ENG-1702 Developer Onboarding Guide

END OF DOCUMENT
