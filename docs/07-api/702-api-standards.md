---
Document ID: API-702

Document Name: API STANDARDS

Book: API Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# API STANDARDS

## Purpose

Определяет обязательные стандарты разработки API SHIK Platform.

---

# Design Principles

- REST First
- Resource Based
- Stateless
- Predictable
- Versioned
- Secure by Default

---

# URL Convention

Resources

```
/orders
/orders/{id}
/products
/products/{id}
```

Nested Resources

```
/orders/{id}/items
/branches/{id}/menus
```

---

# HTTP Methods

GET

Read

POST

Create

PUT

Replace

PATCH

Partial Update

DELETE

Soft Delete

---

# Naming Rules

- lowercase
- plural nouns
- kebab-case where required
- no verbs in URLs

Correct

```
/orders
/products
/payment-methods
```

Incorrect

```
/getOrders
/createOrder
```

---

# Request Headers

Required

```
Authorization
Content-Type
Accept
X-Request-ID
```

Optional

```
Idempotency-Key
Accept-Language
X-Branch-ID
```

---

# Response Rules

Every response contains

- success
- data
- meta
- errors

---

# Pagination

Parameters

- page
- limit

Response

- total
- page
- pages
- limit

---

# Filtering

Supported

- search
- status
- branch
- category
- date_from
- date_to

---

# Sorting

Parameters

- sort
- order

Example

```
?sort=created_at&order=desc
```

---

# Validation

- Request Validation
- DTO Validation
- Business Validation

---

# Error Format

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed"
  }
}
```

---

# Idempotency

Required For

- POST /orders
- POST /payments
- POST /refunds

---

# Security

- HTTPS Only
- JWT Required
- RBAC
- Rate Limiting
- Input Sanitization
- Output Validation

---

# Audit

Log

- User
- Endpoint
- Method
- Duration
- Status Code
- Request ID

---

# API Documentation

Standard

- OpenAPI 3.1

Required

- Summary
- Description
- Parameters
- Request Body
- Responses
- Examples
- Error Codes

---

# Related Documents

API-701 API Overview

ARC-514 Security Architecture

PB-305 Product Requirements

END OF DOCUMENT