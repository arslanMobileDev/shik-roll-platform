---
Document ID: API-715

Document Name: ANALYTICS & REPORTING API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# ANALYTICS & REPORTING API

## Purpose

Определяет REST API аналитики, KPI, отчетов и Dashboard.

---

# Base Endpoint

```text
/analytics
/reports
```

---

# Dashboards

## GET /analytics/dashboard

Purpose

Получить Dashboard текущего пользователя.

Authentication

JWT

---

## GET /analytics/dashboard/widgets

Purpose

Получить список виджетов.

---

## PATCH /analytics/dashboard/widgets

Purpose

Настроить Dashboard.

Permission

analytics.dashboard.update

---

# KPI

## GET /analytics/kpis

Purpose

Получить KPI.

Supports

- Branch
- Date Range
- Period

---

## GET /analytics/kpis/{code}

Purpose

Получить конкретный KPI.

---

# Sales

## GET /analytics/sales

Purpose

Получить статистику продаж.

Supports

- Branch
- Employee
- Date Range
- Payment Method
- Order Type

---

# Orders

## GET /analytics/orders

Purpose

Получить аналитику заказов.

Supports

- Status
- Branch
- Date Range

---

# Products

## GET /analytics/products

Purpose

Получить аналитику товаров.

Supports

- Category
- Branch
- Date Range

---

# Customers

## GET /analytics/customers

Purpose

Получить аналитику клиентов.

Supports

- New Customers
- Returning Customers
- Loyalty Level

---

# Employees

## GET /analytics/employees

Purpose

Получить показатели сотрудников.

Supports

- Branch
- Employee
- Date Range

---

# Reports

## GET /reports

Purpose

Получить список отчетов.

---

## GET /reports/{id}

Purpose

Получить отчет.

---

## POST /reports/generate

Purpose

Сгенерировать отчет.

Permission

report.generate

Request

- report_type
- format
- filters

Formats

- PDF
- XLSX
- CSV

---

## GET /reports/exports

Purpose

Получить историю экспортов.

---

## DELETE /reports/exports/{id}

Purpose

Удалить экспорт.

---

# Audit

## GET /analytics/audit

Purpose

Получить Audit Log.

Permission

audit.view

Supports

- User
- Entity
- Action
- Date Range

---

# System

## GET /analytics/system

Purpose

Получить показатели системы.

Response

- API
- Database
- Queue
- Cache
- Storage

---

# Validation Rules

- Все отчеты формируются фоновыми задачами.
- Экспорт сохраняется в Object Storage.
- Пользователь видит только разрешенные данные.
- Dashboard настраивается индивидуально.
- Все экспорты журналируются.

---

# Events

- ReportGenerated
- ExportCompleted
- DashboardUpdated
- KPICalculated

---

# Error Codes

- REPORT_NOT_FOUND
- EXPORT_NOT_FOUND
- INVALID_FILTER
- INVALID_FORMAT
- ACCESS_DENIED

---

# Security

- JWT Required
- RBAC
- Branch Isolation
- Audit Logging
- Rate Limiting

---

# Related Documents

DB-615 Analytics & Audit Schema

ARC-512 Background Jobs

PB-305 Product Requirements

END OF DOCUMENT