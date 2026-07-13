---
Document ID: BE-912

Document Name: EMPLOYEE SERVICE

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# EMPLOYEE SERVICE

## Purpose

Определяет архитектуру и бизнес-логику Employee Service.

---

# Responsibilities

- Employee Management
- Role Management
- Permission Management
- Branch Assignment
- Shift Management
- Attendance Tracking
- Device Management
- Access Logging

---

# Public API

- Employees
- Roles
- Permissions
- Branch Assignments
- Shifts
- Attendance
- Devices
- Access Logs

---

# Dependencies

- Authentication Service
- Restaurant Service
- Communication Service
- Analytics Service
- Audit Service

---

# Database

Tables

- employees
- employee_roles
- permissions
- role_permissions
- employee_permissions
- employee_branches
- shifts
- attendance
- employee_devices
- access_logs

---

# Events Published

- EmployeeCreated
- EmployeeUpdated
- EmployeeArchived
- RoleAssigned
- RoleRemoved
- ShiftOpened
- ShiftClosed
- AttendanceStarted
- AttendanceFinished
- PermissionUpdated

---

# Events Consumed

- UserRegistered
- BranchCreated
- BranchArchived

---

# Business Rules

- Один сотрудник может работать в нескольких филиалах.
- Основной филиал только один.
- Разрешения определяются через RBAC.
- Индивидуальные разрешения имеют приоритет над ролью.
- Одновременно может быть только одна открытая смена.
- Уволенный сотрудник не может войти в систему.
- Все действия сотрудников журналируются.
- Все изменения публикуются через Event Bus.

---

# Transactions

Atomic Operations

- Create Employee
- Assign Role
- Open Shift
- Close Shift
- Update Permissions

Rollback

Required On Failure

---

# Security

- JWT
- RBAC
- MFA Ready
- Device Tracking
- Audit Logging

---

# Background Jobs

- Shift Auto Close
- Attendance Validation
- Permission Cache Refresh
- Employee Statistics Update

---

# Error Codes

- EMPLOYEE_NOT_FOUND
- ROLE_NOT_FOUND
- PERMISSION_NOT_FOUND
- SHIFT_NOT_FOUND
- DEVICE_NOT_FOUND
- ACCESS_DENIED
- VALIDATION_ERROR

---

# Performance

- Employee Lookup ≤ 100 ms
- Shift Open ≤ 150 ms
- Permission Check ≤ 20 ms
- Attendance Update ≤ 100 ms

---

# Related Documents

API-712 Employee API

DB-612 Employee & Access Schema

BE-903 Authentication Service

ARC-514 Security Architecture

END OF DOCUMENT