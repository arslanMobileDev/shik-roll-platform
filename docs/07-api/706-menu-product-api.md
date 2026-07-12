---
Document ID: API-706

Document Name: MENU & PRODUCT API

Book: API Specification

Version: 1.0.0

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

Загрузить изображение.

---

## DELETE /products/{id}/images/{imageId}

Purpose

Удалить изображение.

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

---

# Security

- JWT Required
- RBAC
- Audit Logging
- Soft Delete

---

# Business Rules

- Меню публикуется без обновления приложения.
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