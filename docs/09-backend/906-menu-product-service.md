---
Document ID: BE-906

Document Name: MENU & PRODUCT SERVICE

Book: Backend Specification

Version: 1.2.0

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
- Catalog Import
- Draft, Preview, Publish and Unpublish Lifecycle
- Category Management
- Category and Product Ordering
- Product Management
- Product Images
- Product Merchandising Flags
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
- Catalog Imports
- Draft Preview
- Categories
- Ordering
- Products
- Product Images
- Product Status and Merchandising
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
- Object Storage Port
- Redis Cache

---

# Database

Tables

- menus
- menu_versions
- catalog_import_jobs
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
- CatalogImported
- MenuPublished
- MenuUnpublished
- ProductCreated
- ProductUpdated
- ProductStatusChanged
- ProductMediaChanged
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
- Импорт JSON или CSV сначала проходит валидацию, а затем применяется в режиме upsert.
- Повторный импорт сопоставляет продукты по `menu_id + source_key` и сохраняет внутренний UUID.
- Перенос продукта между категориями одного меню сохраняет `source_key` и внутренний UUID.
- Product lifecycle определяется только статусами Draft, Published, Hidden и Archived; отдельный флаг `products.is_active` не используется.
- Draft и Preview не доступны через публичный клиентский каталог.
- Publish создает версию меню; Unpublish снимает текущую версию с публичной выдачи.
- Один продукт принадлежит одной категории.
- Один продукт может иметь несколько изображений.
- Изображения сохраняются через Object Storage Port; замена сохраняет позицию в галерее, а удаление выполняется безопасно.
- У продукта может быть только одно активное основное изображение.
- Popular, New и Featured являются независимыми ручными признаками.
- Hidden исключает продукт из публичного каталога, а Stop List временно ограничивает его доступность по филиалу.
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
- Import File Validation
- Media Type and Size Validation

---

# Background Jobs

- Menu Cache Refresh
- Catalog Import Validation
- Catalog Import Upsert
- Published Menu Cache Warmup
- Product Search Index Update
- Image Optimization and Thumbnail Generation
- Deleted Image Cleanup
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
- CATALOG_IMPORT_FAILED
- INVALID_PRODUCT_STATUS_TRANSITION
- IMAGE_STORAGE_ERROR
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

ARC-504 Event-Driven Architecture

ARC-509 Caching Strategy

ARC-512 Background Jobs

BE-905 Restaurant & Branch Service

END OF DOCUMENT
