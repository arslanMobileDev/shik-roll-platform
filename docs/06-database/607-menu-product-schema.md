---
Document ID: DB-607

Document Name: MENU & PRODUCT SCHEMA

Book: Database

Version: 1.2.0

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

# menus

Columns

- id
- branch_id
- name
- status
- current_version
- draft_updated_at
- published_at
- unpublished_at
- created_at
- updated_at

Status Values

- DRAFT
- PUBLISHED
- UNPUBLISHED

---

# menu_versions

Columns

- id
- menu_id
- version_number
- snapshot
- published_by
- published_at

Constraints

- unique menu_id + version_number

Data Types

- snapshot: JSONB

---

# catalog_import_jobs

Columns

- id
- menu_id
- branch_id
- source_format
- source_file_name
- mode
- status
- total_records
- valid_records
- invalid_records
- validation_errors
- created_by
- created_at
- completed_at

Source Format Values

- JSON
- CSV

Mode Values

- VALIDATE
- UPSERT

Status Values

- PENDING
- VALIDATING
- READY
- PROCESSING
- COMPLETED
- FAILED

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

Constraints

- unique id + menu_id

---

# products

Columns

- id
- menu_id
- category_id
- source_key
- sku
- name
- slug
- description
- weight
- calories
- halal_label_id
- preparation_time
- status
- sort_order
- is_popular
- is_new
- is_featured
- published_at
- hidden_at
- archived_at
- created_at
- updated_at

Status Values

- DRAFT
- PUBLISHED
- HIDDEN
- ARCHIVED

Indexes

- sku
- slug
- category_id
- source_key
- menu_id + source_key

Constraints

- unique menu_id + source_key
- category_id + menu_id references menu_categories id + menu_id

---

# product_images

Columns

- id
- product_id
- provider
- object_key
- image_url
- mime_type
- size_bytes
- width
- height
- processing_status
- status
- sort_order
- is_primary
- deleted_at
- created_at
- updated_at

Processing Status Values

- PENDING
- PROCESSING
- READY
- FAILED

Status Values

- ACTIVE
- DELETED

Constraints

- unique provider + object_key
- one active primary image per product

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

menu_versions

---

menus

↓

catalog_import_jobs

---

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
- `source_key` является стабильным внешним ключом импорта внутри одного меню и не заменяет внутренний UUID продукта.
- Повторный импорт обновляет продукт по `menu_id + source_key` и не создает дубликат.
- Перенос продукта между категориями одного меню сохраняет `source_key` и внутренний UUID.
- `products.status` является единственным полем жизненного цикла продукта; отдельное `products.is_active` не используется.
- Product lifecycle использует статусы Draft, Published и Hidden.
- Публикация создает неизменяемый snapshot в `menu_versions`.
- Один продукт может иметь несколько изображений.
- Метаданные изображения хранятся в PostgreSQL, а файл — через provider-agnostic Object Storage Port.
- Удаление изображения выполняется мягко; очистка объекта может завершаться асинхронно.
- У продукта может быть только одно активное основное изображение.
- Popular, New и Featured являются независимыми ручными признаками.
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
