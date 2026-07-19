---
Document ID: UI-805

Document Name: BACK OFFICE UX

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

# BACK OFFICE UX

## Purpose

Определяет UX Back Office SHIK Platform.

---

# Navigation

Sidebar

- Dashboard
- Orders
- Menu
- Customers
- Employees
- Inventory
- Kitchen
- Delivery
- Loyalty
- Communications
- Analytics
- Settings

---

# Dashboard

Widgets

- Revenue
- Orders
- Average Order
- Active Customers
- Kitchen Status
- Delivery Status
- Low Stock
- Notifications

---

# Orders

Screens

- Order List
- Order Details
- Status Timeline
- Refund
- Search
- Filters

---

# Menu

Screens

- Catalog Import
- Import Job Details
- Menus
- Draft Catalog
- Catalog Preview
- Categories
- Category Ordering
- Products
- Product Editor
- Media Gallery
- Modifiers
- Prices
- Branch Availability
- Stop List
- Publish History

Catalog Workflow

1. Импортировать JSON или CSV либо создать каталог вручную.
2. Проверить результаты валидации и ошибки импорта.
3. Редактировать категории и блюда в статусе Draft.
4. Открыть Preview без публикации изменений клиентам.
5. Опубликовать подготовленную версию каталога или снять ее с публикации.

Product Editor Actions

- Изменить название, описание, состав, вес и цену.
- Установить статус Draft, Published или Hidden.
- Включить или выключить признаки Popular, New и Featured.
- Загрузить, заменить и безопасно удалить изображение.
- Выбрать основное изображение и изменить порядок галереи.
- Изменить порядок блюда внутри категории.
- Управлять доступностью и Stop List отдельно для каждого филиала.

UX Safeguards

- Импорт до применения показывает количество валидных и ошибочных записей.
- Повторный импорт использует стабильный `source_key` и не создает дубли блюд.
- Удаление используемого изображения требует подтверждения и выполняется безопасно.
- Preview явно показывает, что Draft-изменения еще не видны клиентам.
- Publish и Unpublish требуют подтверждения и создают запись в истории публикаций.

---

# Customers

Screens

- Customer List
- Customer Profile
- Loyalty
- Orders
- Communication History

---

# Employees

Screens

- Employee List
- Roles
- Permissions
- Shifts
- Attendance

---

# Inventory

Screens

- Warehouses
- Ingredients
- Stock
- Transfers
- Inventory Count
- Suppliers

---

# Kitchen

Screens

- Kitchen Dashboard
- Stations
- Queue
- Recipes

---

# Delivery

Screens

- Couriers
- Deliveries
- Routes
- Live Map

---

# Loyalty

Screens

- Promotions
- Coupons
- Loyalty Levels
- Gift Certificates

---

# Communications

Screens

- Templates
- Automation Rules
- Message Queue
- Delivery Logs

---

# Analytics

Screens

- Dashboard
- Reports
- KPI
- Exports
- Audit Logs

---

# Settings

Screens

- Restaurant
- Branches
- Payment
- Maps
- Communication
- Users
- System

---

# Global Components

- Global Search
- Notifications
- Command Palette
- Breadcrumbs
- Filters
- Data Tables
- Charts
- Modal Dialogs

---

# States

- Empty
- Loading
- Error
- Success
- Offline

---

# Accessibility

- WCAG AA
- Keyboard Navigation
- Screen Reader Support
- High Contrast

---

# UX Principles

- Desktop First
- Fast Navigation
- Minimal Clicks
- Consistent Layout
- Responsive
- Role Based Interface

---

# Related Documents

UI-802 Design System

UI-803 Component Library

PB-305 Product Requirements

END OF DOCUMENT
