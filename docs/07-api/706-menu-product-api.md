---
Document ID: API-706

Document Name: MENU & PRODUCT API

Book: API Specification

Version: 1.2.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# MENU & PRODUCT API

## Purpose

Определяет REST API управления меню, категориями, продуктами и модификаторами.

---

# Base Endpoints

```
/menus
/categories
/products
/modifiers
```

---

# Menu Endpoints

## GET /menus

Purpose

Получить список меню.

---

## GET /menus/{id}

Purpose

Получить меню.

---

## POST /menus

Purpose

Создать меню.

Permission

menu.create

---

## PATCH /menus/{id}

Purpose

Изменить меню.

Permission

menu.update

---

## POST /menus/{id}/publish

Purpose

Опубликовать меню.

Permission

menu.publish

---

## POST /menus/{id}/unpublish

Purpose

Снять опубликованную версию меню с публикации.

Permission

menu.publish

---

## POST /menus/{id}/imports

Purpose

Проверить или импортировать каталог из JSON или CSV.

Request

- format: JSON | CSV
- branch_id
- source_file
- mode: VALIDATE | UPSERT

Response

- import_job_id
- status
- valid_records
- invalid_records
- errors

---

## GET /menus/{id}/imports/{jobId}

Purpose

Получить статус и результаты задания импорта.

---

## GET /menus/{id}/preview

Purpose

Получить Draft-версию меню для предпросмотра без публикации.

---

## DELETE /menus/{id}

Purpose

Архивировать меню.

---

# Category Endpoints

## GET /categories

Purpose

Получить категории.

---

## POST /categories

Purpose

Создать категорию.

---

## PATCH /categories/{id}

Purpose

Изменить категорию.

---

## DELETE /categories/{id}

Purpose

Архивировать категорию.

---

## PATCH /categories/order

Purpose

Изменить порядок категорий в меню.

---

## PATCH /categories/{id}/products/order

Purpose

Изменить порядок продуктов внутри категории.

---

# Product Endpoints

## GET /products

Purpose

Получить список продуктов.

Supports

- Search
- Pagination
- Filters
- Sorting

---

## GET /products/{id}

Purpose

Получить продукт.

---

## GET /products/{id}/preview

Purpose

Получить Draft-представление продукта для Back Office.

---

## POST /products

Purpose

Создать продукт.

Permission

product.create

---

## PATCH /products/{id}

Purpose

Изменить продукт.

Permission

product.update

---

## PATCH /products/{id}/status

Purpose

Изменить жизненный цикл продукта.

Request

- status: DRAFT | PUBLISHED | HIDDEN

---

## PATCH /products/{id}/merchandising

Purpose

Изменить ручные признаки продвижения продукта.

Request

- is_popular
- is_new
- is_featured

---

## DELETE /products/{id}

Purpose

Архивировать продукт.

---

## PATCH /products/{id}/availability

Purpose

Изменить доступность продукта.

Request

- branch_id
- is_available

---

## PATCH /products/{id}/price

Purpose

Изменить цену.

Request

- branch_id
- price

---

## PATCH /products/{id}/stop-list

Purpose

Добавить или убрать продукт из Stop List.

Request

- branch_id
- is_active
- reason

---

# Product Images

## POST /products/{id}/images

Purpose

Загрузить изображение через Object Storage Port.

---

## PUT /products/{id}/images/{imageId}

Purpose

Заменить файл изображения с сохранением позиции в галерее.

---

## PATCH /products/{id}/images/{imageId}

Purpose

Изменить основное изображение или порядок в галерее.

Request

- is_primary
- sort_order

---

## DELETE /products/{id}/images/{imageId}

Purpose

Безопасно пометить изображение удаленным и запустить асинхронную очистку Object Storage.

---

# Modifiers

## GET /modifier-groups

---

## POST /modifier-groups

---

## PATCH /modifier-groups/{id}

---

## DELETE /modifier-groups/{id}

---

## GET /modifiers

---

## POST /modifiers

---

## PATCH /modifiers/{id}

---

## DELETE /modifiers/{id}

---

# Allergens

## GET /allergens

---

## POST /products/{id}/allergens

---

## DELETE /products/{id}/allergens/{allergenId}

---

# Halal

## GET /halal-labels

---

## PATCH /products/{id}/halal

Request

- halal_label_id

---

# Nutrition

## GET /products/{id}/nutrition

---

## PATCH /products/{id}/nutrition

---

# Error Codes

- MENU_NOT_FOUND
- CATEGORY_NOT_FOUND
- PRODUCT_NOT_FOUND
- MODIFIER_NOT_FOUND
- INVALID_PRICE
- STOP_LIST_ACTIVE
- VALIDATION_ERROR
- CATALOG_IMPORT_FAILED
- CATALOG_IMPORT_FORMAT_UNSUPPORTED
- INVALID_PRODUCT_STATUS_TRANSITION
- IMAGE_IN_USE
- IMAGE_STORAGE_ERROR

---

# Security

- JWT Required
- RBAC
- Audit Logging
- Soft Delete

---

# Business Rules

- Меню публикуется без обновления приложения.
- Импорт выполняется повторяемо: `menu_id + source_key` используется для upsert, а внутренний UUID не меняется.
- Перенос продукта между категориями одного меню не меняет `source_key` или внутренний UUID.
- Product lifecycle использует статусы Draft, Published, Hidden и Archived; DELETE переводит продукт в Archived.
- Отдельное поле `products.is_active` не используется.
- Preview возвращает Draft-данные, не доступные клиентскому каталогу.
- Stop List управляет временной доступностью опубликованного продукта по филиалу и не заменяет Hidden.
- Popular, New и Featured являются независимыми ручными признаками.
- Медиа сохраняются через provider-agnostic Object Storage Port.
- Цена может отличаться по филиалам.
- Stop List работает отдельно для каждого филиала.
- Один продукт может иметь несколько модификаторов.
- Один продукт может иметь несколько изображений.
- Все изменения журналируются.

---

# Related Documents

DB-607 Menu & Product Schema

PB-305 Product Requirements

ARC-505 Domain Model

END OF DOCUMENT
