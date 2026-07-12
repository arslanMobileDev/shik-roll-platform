---
Document ID: DB-602

Document Name: DATABASE STANDARDS

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

# DATABASE STANDARDS

## Purpose

Определяет обязательные стандарты проектирования базы данных SHIK Platform.

---

# Naming

Tables

- snake_case
- plural

Examples

- customers
- orders
- products

Columns

- snake_case

Primary Key

- id

Foreign Keys

- customer_id
- order_id
- branch_id

Indexes

- idx_table_column

Unique Indexes

- uq_table_column

Foreign Keys

- fk_table_reference

---

# Primary Keys

Type

- UUID v7

Fallback

- UUID v4

---

# Required Columns

Every business table contains

- id
- created_at
- updated_at
- deleted_at
- created_by
- updated_by
- version

---

# Date & Time

Storage

- UTC

Type

- timestamptz

---

# Money

Storage

- Integer (Minor Units)

Examples

10.50 USD

Stored

1050

---

# Boolean

Default

false

---

# Enums

Use PostgreSQL ENUM only for stable values.

Frequently changing values must use lookup tables.

---

# Foreign Keys

- Required whenever relationship exists.
- ON DELETE RESTRICT by default.
- CASCADE only where explicitly approved.

---

# Constraints

Use

- NOT NULL
- UNIQUE
- CHECK
- FOREIGN KEY

Avoid application-only validation.

---

# Indexing Rules

Create indexes for

- Primary Keys
- Foreign Keys
- Frequently filtered columns
- Frequently sorted columns
- Search columns

---

# Soft Delete

Use

deleted_at

Never physically delete production business data without approved archival policy.

---

# Audit

Critical tables must support auditing.

Audit fields are mandatory.

---

# Transactions

Required for

- Orders
- Payments
- Inventory
- Loyalty
- Refunds

---

# Migrations

Rules

- Forward Only
- Version Controlled
- Repeatable
- Reviewed before Production

---

# Performance

Avoid

- SELECT *
- N+1 Queries
- Missing Indexes

Use

- Pagination
- Batch Operations
- Prepared Statements

---

# Security

- Principle of Least Privilege
- Parameterized Queries
- No Dynamic SQL without validation
- Encryption where required

---

# Documentation

Every table must have

- Description
- Owner
- Relationships
- Indexes
- Business Purpose

---

# Related Documents

DB-601 Database Overview

ARC-505 Domain Model

ARC-508 Technology Stack

END OF DOCUMENT