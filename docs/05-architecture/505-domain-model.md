---
Document ID: ARC-505

Document Name: DOMAIN MODEL

Book: Architecture

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# DOMAIN MODEL

## Purpose

Определяет основные домены, агрегаты и сущности SHIK Platform.

---

# Domain Structure

Restaurant

├── Branch

├── Employee

├── Menu

├── Inventory

├── Kitchen

├── Orders

├── Payments

├── Promotions

└── Analytics

---

# Customer Domain

Aggregate Root

Customer

Entities

- Customer
- Address
- Favorite
- LoyaltyAccount
- Device
- NotificationPreference

---

# Restaurant Domain

Aggregate Root

Restaurant

Entities

- Restaurant
- Branch
- WorkingHours
- DeliveryZone
- HolidaySchedule

---

# Menu Domain

Aggregate Root

Menu

Entities

- Menu
- Category
- Product
- ModifierGroup
- Modifier
- ProductImage
- ProductPrice
- StopListItem

---

# Order Domain

Aggregate Root

Order

Entities

- Order
- OrderItem
- OrderStatus
- OrderComment
- Discount
- Coupon

---

# Payment Domain

Aggregate Root

Payment

Entities

- Payment
- Transaction
- Refund
- PaymentMethod

---

# Kitchen Domain

Aggregate Root

KitchenOrder

Entities

- KitchenOrder
- KitchenStation
- Recipe
- PreparationTimer

---

# Delivery Domain

Aggregate Root

Delivery

Entities

- Delivery
- Courier
- Route
- DeliveryStatus

---

# Inventory Domain

Aggregate Root

Inventory

Entities

- Ingredient
- Warehouse
- Stock
- StockMovement
- InventoryAdjustment

---

# Employee Domain

Aggregate Root

Employee

Entities

- Employee
- Role
- Permission
- Shift
- DeviceSession

---

# Communication Domain

Aggregate Root

Communication

Entities

- CommunicationRule
- Template
- Channel
- Message
- DeliveryLog
- Campaign

---

# Analytics Domain

Aggregate Root

Analytics

Entities

- Dashboard
- KPI
- SalesReport
- ProductStatistics

---

# Shared Value Objects

- Money
- Address
- GeoLocation
- PhoneNumber
- Email
- WorkingHours
- Quantity
- Percentage
- Currency
- Language

---

# Aggregate Rules

- Один Aggregate Root управляет своими сущностями.
- Прямое изменение дочерних сущностей запрещено.
- Все изменения проходят через Aggregate Root.
- Между агрегатами используются только идентификаторы.

---

# Domain Principles

- High Cohesion
- Low Coupling
- Rich Domain Model
- Business First
- Event Driven
- API First

---

# Related Documents

ARC-501 System Overview

ARC-502 Modular Architecture

ARC-504 Event Driven Architecture

DB-601 Database Overview

PB-305 Product Requirements

END OF DOCUMENT