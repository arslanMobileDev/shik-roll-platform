---
Document ID: API-712

Document Name: EMPLOYEE API

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# EMPLOYEE API

## Purpose

Определяет REST API управления сотрудниками, ролями, разрешениями и сменами.

---

# Base Endpoint

```text
/employees
```

---

# Employee Endpoints

## GET /employees

Purpose

Получить список сотрудников.

Supports

- Search
- Branch
- Role
- Status
- Pagination

---

## GET /employees/{id}

Purpose

Получить сотрудника.

---

## POST /employees

Purpose

Создать сотрудника.

Permission

employee.create

---

## PATCH /employees/{id}

Purpose

Изменить сотрудника.

Permission

employee.update

---

## DELETE /employees/{id}

Purpose

Архивировать сотрудника.

Permission

employee.delete

---

# Roles

## GET /employees/roles

---

## POST /employees/roles

Permission

role.create

---

## PATCH /employees/roles/{id}

Permission

role.update

---

## DELETE /employees/roles/{id}

Permission

role.delete

---

## POST /employees/{id}/roles

Purpose

Назначить роль.

Permission

role.assign

Request

- role_id
- branch_id

---

## DELETE /employees/{id}/roles/{roleId}

Purpose

Удалить роль.

Permission

role.assign

---

# Permissions

## GET /employees/permissions

---

## POST /employees/{id}/permissions

Purpose

Назначить индивидуальное разрешение.

Permission

permission.assign

Request

- permission_id
- granted

---

## DELETE /employees/{id}/permissions/{permissionId}

Purpose

Удалить индивидуальное разрешение.

Permission

permission.assign

---

# Branch Assignment

## GET /employees/{id}/branches

---

## POST /employees/{id}/branches

Purpose

Назначить филиал.

Request

- branch_id
- is_primary

---

## DELETE /employees/{id}/branches/{branchId}

---

# Shifts

## GET /employees/shifts

---

## POST /employees/shifts

Purpose

Открыть смену.

Request

- employee_id
- branch_id

---

## PATCH /employees/shifts/{id}/close

Purpose

Закрыть смену.

---

# Attendance

## POST /employees/attendance/check-in

Purpose

Отметить начало рабочего дня.

---

## POST /employees/attendance/check-out

Purpose

Отметить окончание рабочего дня.

---

# Devices

## GET /employees/{id}/devices

---

## DELETE /employees/{id}/devices/{deviceId}

Purpose

Отключить устройство.

---

# Access Logs

## GET /employees/{id}/access-logs

Purpose

Получить журнал действий сотрудника.

Permission

audit.view

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

# Validation Rules

- Один сотрудник может работать в нескольких филиалах.
- Основной филиал может быть только один.
- Роли проверяются через RBAC.
- Все изменения разрешений журналируются.
- Закрытая смена не может быть изменена.
- Уволенный сотрудник не может входить в систему.

---

# Events

- EmployeeCreated
- EmployeeUpdated
- EmployeeAssignedToBranch
- ShiftOpened
- ShiftClosed
- PermissionChanged

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

# Security

- JWT Required
- RBAC
- Branch Isolation
- Audit Logging
- Device Tracking

---

# Related Documents

DB-612 Employee & Access Schema

API-703 Authentication API

ARC-514 Security Architecture

END OF DOCUMENT