---
Document ID: DB-603

Document Name: ENTITY RELATIONSHIP MODEL

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

# ENTITY RELATIONSHIP MODEL

## Purpose

Определяет домены базы данных, основные сущности и связи между ними.

---

# Domain Groups

- Identity
- Customers
- Restaurants
- Menu
- Orders
- Payments
- Kitchen
- Delivery
- Inventory
- Employees
- Loyalty
- Promotions
- Communications
- Analytics
- Audit
- Configuration

---

# Identity

Tables

- users
- roles
- permissions
- role_permissions
- user_roles
- sessions
- otp_codes
- refresh_tokens

---

# Customers

Tables

- customers
- customer_addresses
- customer_devices
- customer_favorites
- customer_preferences
- customer_loyalty_accounts

---

# Restaurants

Tables

- restaurants
- branches
- branch_settings
- working_hours
- delivery_zones

---

# Menu

Tables

- menus
- menu_categories
- products
- product_images
- product_prices
- modifier_groups
- modifiers
- product_modifiers
- stop_list

---

# Orders

Tables

- carts
- cart_items
- orders
- order_items
- order_status_history
- order_comments

---

# Payments

Tables

- payments
- payment_transactions
- refunds
- payment_methods

---

# Kitchen

Tables

- kitchen_orders
- kitchen_stations
- recipes
- preparation_steps

---

# Delivery

Tables

- deliveries
- couriers
- courier_locations
- delivery_routes

---

# Inventory

Tables

- ingredients
- warehouses
- inventory
- stock_movements
- inventory_adjustments

---

# Employees

Tables

- employees
- employee_roles
- employee_permissions
- shifts

---

# Loyalty

Tables

- loyalty_accounts
- loyalty_transactions
- loyalty_levels

---

# Promotions

Tables

- promotions
- promotion_rules
- coupons
- campaigns

---

# Communication

Tables

- communication_rules
- templates
- messages
- delivery_logs

---

# Analytics

Tables

- dashboards
- reports
- kpis

---

# Audit

Tables

- audit_logs
- security_logs

---

# Configuration

Tables

- settings
- feature_flags

---

# Main Relationships

Restaurant

↓

Branches

↓

Menus

↓

Categories

↓

Products

↓

Modifiers

---

Customer

↓

Orders

↓

Payments

↓

Delivery

↓

Loyalty

---

Products

↓

Recipes

↓

Ingredients

↓

Inventory

---

Employees

↓

Kitchen

↓

Orders

↓

Audit

---

# Design Rules

- Aggregate Root owns child entities.
- Foreign Keys are mandatory.
- No circular dependencies.
- Junction tables for Many-to-Many relationships.
- Soft Delete for business entities.

---

# Estimated Tables

Current

≈70

Target

120–180

---

# Related Documents

DB-601 Database Overview

DB-602 Database Standards

ARC-505 Domain Model

PB-305 Product Requirements

END OF DOCUMENT