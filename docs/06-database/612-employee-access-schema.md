---
Document ID: DB-612

Document Name: EMPLOYEE & ACCESS SCHEMA

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

# EMPLOYEE & ACCESS SCHEMA

## Purpose

Определяет структуру хранения сотрудников, ролей, разрешений и контроля доступа.

---

# Tables

- employees
- employee_profiles
- employee_roles
- employee_permissions
- employee_branches
- employee_devices
- employee_sessions
- shifts
- attendance
- access_logs

---

# employees

Columns

- id
- user_id
- employee_number
- first_name
- last_name
- phone
- email
- hire_date
- status
- created_at
- updated_at

---

# employee_profiles

Columns

- id
- employee_id
- position
- department
- avatar_url
- notes

---

# employee_roles

Columns

- id
- employee_id
- role_id
- assigned_at
- assigned_by

---

# employee_permissions

Columns

- id
- employee_id
- permission_id
- granted
- assigned_by

---

# employee_branches

Columns

- id
- employee_id
- branch_id
- is_primary

---

# employee_devices

Columns

- id
- employee_id
- device_name
- platform
- app_version
- trusted
- last_seen_at

---

# employee_sessions

Columns

- id
- employee_id
- device_id
- ip_address
- user_agent
- started_at
- expires_at
- revoked_at

---

# shifts

Columns

- id
- employee_id
- branch_id
- started_at
- ended_at
- status

---

# attendance

Columns

- id
- employee_id
- shift_id
- check_in
- check_out

---

# access_logs

Columns

- id
- employee_id
- action
- module
- ip_address
- created_at

---

# Relationships

employees

↓

employee_profiles

↓

employee_roles

↓

employee_permissions

↓

employee_branches

↓

shifts

↓

attendance

↓

access_logs

---

# Employee Status

- Active
- Suspended
- On Leave
- Terminated

---

# Shift Status

- Scheduled
- Open
- Closed
- Cancelled

---

# Business Rules

- Один сотрудник может работать в нескольких филиалах.
- Один филиал назначается основным.
- Роли назначаются независимо от учетной записи.
- Разрешения могут дополнять роль.
- Все входы журналируются.
- Все действия сотрудников журналируются.
- После увольнения новые сессии запрещены.
- PIN и пароли никогда не хранятся в открытом виде.

---

# Security

- RBAC
- Least Privilege
- Audit Enabled
- Soft Delete
- Device Tracking

---

# Related Documents

DB-604 Identity Schema

ARC-514 Security Architecture

PB-305 Product Requirements

END OF DOCUMENT