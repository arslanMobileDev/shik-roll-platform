---
Document ID: DB-607

Document Name: MENU & PRODUCT SCHEMA

Book: Database

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Database: PostgreSQL

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# MENU & PRODUCT SCHEMA

## Purpose

Определяет структуру меню, категорий, продуктов и связанных сущностей.

---

# Tables

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

# menus

Columns

- id
- branch_id
- name
- status
- published_at
- created_at
- updated_at

---

# menu_categories

Columns

- id
- menu_id
- parent_id
- name
- description
- image_url
- sort_order
- is_active

---

# products

Columns

- id
- category_id
- sku
- name
- slug
- description
- weight
- calories
- halal_label_id
- preparation_time
- is_featured
- is_active
- created_at
- updated_at

Indexes

- sku
- slug
- category_id

---

# product_images

Columns

- id
- product_id
- image_url
- sort_order
- is_primary

---

# product_prices

Columns

- id
- product_id
- branch_id
- price
- old_price
- currency
- valid_from
- valid_to

---

# modifier_groups

Columns

- id
- name
- selection_type
- min_selected
- max_selected
- required

---

# modifiers

Columns

- id
- group_id
- name
- price
- calories
- is_active

---

# product_modifiers

Columns

- id
- product_id
- modifier_group_id

---

# allergens

Columns

- id
- code
- name
- icon

---

# product_allergens

Columns

- id
- product_id
- allergen_id

---

# halal_labels

Columns

- id
- code
- name
- description
- icon

---

# nutrition

Columns

- id
- product_id
- proteins
- fats
- carbohydrates
- calories

---

# stop_list

Columns

- id
- product_id
- branch_id
- reason
- starts_at
- ends_at
- is_active

---

# recommendations

Columns

- id
- product_id
- recommended_product_id
- priority

---

# branch_product_availability

Columns

- id
- branch_id
- product_id
- is_available

---

# Relationships

menus

↓

menu_categories

↓

products

↓

product_images

↓

product_prices

↓

modifier_groups

↓

modifiers

---

products

↓

allergens

↓

nutrition

↓

recommendations

↓

stop_list

↓

branch_product_availability

---

# Business Rules

- Один продукт принадлежит одной категории.
- Один продукт может иметь несколько изображений.
- Один продукт может иметь несколько модификаторов.
- Один продукт может иметь несколько аллергенов.
- Один продукт может иметь одну халяльную маркировку.
- Цена может отличаться по филиалам.
- Доступность продукта определяется отдельно для каждого филиала.
- Стоп-лист действует только для указанного филиала.

---

# Related Documents

PB-305 Product Requirements

ARC-505 Domain Model

DB-606 Restaurant & Branch Schema

END OF DOCUMENT