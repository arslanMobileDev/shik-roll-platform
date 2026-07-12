---
Document ID: DB-615

Document Name: ANALYTICS & AUDIT SCHEMA

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

# ANALYTICS & AUDIT SCHEMA

## Purpose

Определяет структуру аналитики, KPI, отчетности и аудита.

---

# Tables

- dashboards
- dashboard_widgets
- reports
- report_exports
- kpis
- analytics_snapshots
- audit_logs
- security_logs
- api_logs
- system_events

---

# dashboards

Columns

- id
- name
- owner_type
- owner_id
- is_default
- created_at
- updated_at

---

# dashboard_widgets

Columns

- id
- dashboard_id
- widget_type
- configuration
- sort_order

---

# reports

Columns

- id
- code
- name
- description
- report_type
- created_at

---

# report_exports

Columns

- id
- report_id
- format
- file_url
- generated_by
- generated_at

Formats

- PDF
- XLSX
- CSV

---

# kpis

Columns

- id
- code
- name
- value
- period
- branch_id
- calculated_at

---

# analytics_snapshots

Columns

- id
- snapshot_date
- branch_id
- total_orders
- total_revenue
- average_order
- completed_orders
- cancelled_orders

---

# audit_logs

Columns

- id
- entity_type
- entity_id
- action
- user_id
- branch_id
- old_value
- new_value
- ip_address
- user_agent
- created_at

---

# security_logs

Columns

- id
- user_id
- event_type
- severity
- ip_address
- metadata
- created_at

---

# api_logs

Columns

- id
- endpoint
- method
- status_code
- duration_ms
- request_id
- created_at

---

# system_events

Columns

- id
- event_type
- source
- payload
- severity
- created_at

---

# Relationships

Dashboards

↓

Widgets

↓

Reports

↓

Exports

---

Orders

↓

Analytics

↓

KPIs

↓

Dashboards

---

Users

↓

Audit Logs

↓

Security Logs

---

# Audit Actions

- Create
- Update
- Delete
- Login
- Logout
- Export
- Refund
- Payment
- Permission Change

---

# Severity

- Info
- Warning
- Error
- Critical

---

# Business Rules

- Audit записи не изменяются.
- Audit записи не удаляются.
- Все критические действия журналируются.
- KPI рассчитываются фоновыми задачами.
- Отчеты могут генерироваться повторно.
- Экспорт сохраняется в Object Storage.
- API журналируется без хранения чувствительных данных.

---

# Retention Policy

Audit Logs

- 5 Years

Security Logs

- 5 Years

API Logs

- 90 Days

Analytics Snapshots

- Permanent

---

# Related Documents

DB-608 Order Schema

DB-609 Payment Schema

ARC-512 Background Jobs

ARC-514 Security Architecture

END OF DOCUMENT