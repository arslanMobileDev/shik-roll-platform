---
Document ID: DB-601

Document Name: DATABASE OVERVIEW

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

# DATABASE OVERVIEW

## Purpose

Определяет концепцию базы данных SHIK Platform.

---

# Database Engine

Primary Database

- PostgreSQL

Cache

- Redis

Object Storage

- Provider-neutral Object Storage Port
- Google Cloud Storage (Production)
- MinIO (Local / Development)
- S3-compatible providers (Alternative)

---

# Database Principles

- Single Source of Truth
- ACID Transactions
- Normalized Design
- UUID Primary Keys
- Soft Delete
- Audit Ready
- Multi Branch Ready
- Multi Tenant Ready
- Event Driven Ready

---

# Naming Convention

Tables

snake_case

Examples

- customers
- orders
- order_items
- menu_categories
- payment_transactions

Columns

snake_case

Primary Key

id

Foreign Keys

entity_id

Examples

- customer_id
- order_id
- branch_id

---

# Common Columns

Every Business Table Contains

- id
- created_at
- updated_at
- deleted_at
- created_by
- updated_by
- version

---

# Database Domains

- Identity
- Customers
- Restaurants
- Branches
- Employees
- Menu
- Products
- Orders
- Payments
- Kitchen
- Delivery
- Inventory
- Loyalty
- Promotions
- Communications
- Analytics
- Audit
- Configuration

---

# Relationships

One To One

One To Many

Many To Many

---

# Soft Delete

Business entities use:

deleted_at

Records are never physically deleted unless explicitly archived or purged.

---

# Audit

Every critical change is stored in Audit Log.

---

# Transactions

Required For

- Orders
- Payments
- Inventory
- Loyalty
- Refunds

---

# Indexing Strategy

Primary Keys

Foreign Keys

Unique Keys

Search Indexes

Composite Indexes

---

# UUID Policy

Primary Keys

UUID v7 (preferred)

Fallback

UUID v4

---

# Time Standard

UTC Only

Display Time

Restaurant Time Zone

---

# Currency

Stored As

Minor Units

Example

10.50 USD

Stored As

1050

---

# Related Documents

ARC-505 Domain Model

ARC-508 Technology Stack

ADR-1612 Object Storage Provider Model

PB-305 Product Requirements

END OF DOCUMENT