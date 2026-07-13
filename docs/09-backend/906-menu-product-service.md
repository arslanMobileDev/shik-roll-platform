---
Document ID: BE-906

Document Name: MENU & PRODUCT SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# MENU & PRODUCT SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Menu & Product Service.

---

# Responsibilities

- Menu Management
- Category Management
- Product Management
- Product Images
- Product Pricing
- Modifier Management
- Allergen Management
- Halal Labels
- Nutrition Information
- Stop List
- Product Availability
- Recommendations

---

# Public API

- Menus
- Categories
- Products
- Product Images
- Prices
- Modifiers
- Allergens
- Halal Labels
- Nutrition
- Stop List
- Availability

---

# Dependencies

- Restaurant Service
- Inventory Service
- Order Service
- Kitchen Service
- Audit Service

---

# Database

Tables

- menus
- menu_categories
- products
- product_images
- product_prices
- modifier_groups
- modifiers
- product_modifiers
- allergens
- product_allergens
- halal_labels
- nutrition
- stop_list
- recommendations
- branch_product_availability

---

# Events Published

- MenuCreated
- MenuPublished
- ProductCreated
- ProductUpdated
- ProductDeleted
- ProductPriceChanged
- ProductAvailabilityChanged
- StopListUpdated

---

# Events Consumed

- InventoryUpdated
- BranchCreated
- ProductRecipeUpdated

---

# Business Rules

- Меню публикуется без перезапуска системы.
- Один продукт принадлежит одной категории.
- Один продукт может иметь несколько изображений.
- Один продукт может иметь несколько модификаторов.
- Один продукт может иметь несколько аллергенов.
- Один продукт может иметь одну халяльную маркировку.
- Цена определяется отдельно для каждого филиала.
- Stop List определяется отдельно для каждого филиала.
- Недоступность ингредиентов может автоматически активировать Stop List.

---

# Security

- JWT
- RBAC
- Audit Logging
- Soft Delete
- Input Validation

---

# Background Jobs

- Menu Cache Refresh
- Product Search Index Update
- Stop List Synchronization
- Recommendation Recalculation

---

# Error Codes

- MENU_NOT_FOUND
- CATEGORY_NOT_FOUND
- PRODUCT_NOT_FOUND
- MODIFIER_NOT_FOUND
- INVALID_PRICE
- PRODUCT_UNAVAILABLE
- STOP_LIST_ACTIVE
- ACCESS_DENIED

---

# Performance

- Menu Load ≤ 200 ms
- Product Search ≤ 150 ms
- Price Update ≤ 100 ms
- Stop List Refresh ≤ 5 sec

---

# Related Documents

API-706 Menu & Product API

DB-607 Menu & Product Schema

BE-905 Restaurant & Branch Service

END OF DOCUMENT