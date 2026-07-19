---
Document ID: QA-1304

Document Name: API TESTING SPECIFICATION

Book: Testing & Quality Assurance

Version: 1.2.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# API TESTING SPECIFICATION

## Purpose

Определяет стандарты тестирования REST API SHIK Platform.

---

# Objectives

- Validate API Contracts
- Verify Business Rules
- Ensure Backward Compatibility
- Detect Integration Issues

---

# Scope

Test

- REST API
- Authentication
- Authorization
- Validation
- Error Handling
- Pagination
- Filtering
- Webhooks

---

# Framework

- Jest
- Supertest
- Postman
- Newman

---

# API Validation

Verify

- HTTP Methods
- Status Codes
- Headers
- Request Body
- Response Body
- Error Responses

---

# Authentication

Validate

- JWT
- Refresh Token
- RBAC
- Permission Checks

---

# Input Validation

Test

- Required Fields
- Invalid Values
- Boundary Values
- Empty Requests
- Malformed Requests

---

# Response Validation

Verify

- Schema
- Data Types
- Required Fields
- Response Time

---

# Menu Catalog API Scenarios

Validate

- JSON and CSV import validation without applying changes
- Repeatable upsert by `menu_id + source_key` without duplicate products or changed internal UUID
- Category move without changed `source_key` or internal UUID
- Import job status and row-level validation errors
- Draft, Published and Hidden status transitions
- Preview isolation from the public catalog
- Publish and Unpublish behavior
- Category and product ordering
- Popular, New and Featured flags
- Branch availability and Stop List isolation
- Image upload, replacement, primary selection, ordering and safe deletion

---

# Error Handling

Validate

- 400 Bad Request
- 401 Unauthorized
- 403 Forbidden
- 404 Not Found
- 409 Conflict
- 422 Validation Error
- 500 Internal Server Error

---

# Performance

Targets

- GET ≤ 200 ms
- POST ≤ 500 ms
- PUT ≤ 500 ms
- DELETE ≤ 300 ms

---

# Security Tests

Verify

- Authorization
- Rate Limiting
- Input Sanitization
- SQL Injection Protection
- XSS Protection
- Idempotency
- File Type and Size Validation
- Unauthorized Catalog Publication
- Cross-Branch Catalog Access
- Product and Image IDOR

---

# Execution

Run

- Every Pull Request
- CI Pipeline
- Before Release

---

# Reporting

Include

- Passed Tests
- Failed Tests
- Coverage
- Response Time
- Error Summary

---

# Related Documents

QA-1301 Testing Overview

API-701 API Overview

API-706 Menu & Product API

SEC-1104 API Security

END OF DOCUMENT
