---
Document ID: RTM-001

Document Name: REQUIREMENTS TRACEABILITY MATRIX

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Standard: IEEE 29148 (Adapted)

Owner: Arslan Berslanov
Last Updated: July 2026


Classification: Internal
---

# REQUIREMENTS TRACEABILITY MATRIX (RTM)

## Purpose

Requirements Traceability Matrix (RTM) обеспечивает полную прослеживаемость требований проекта SHIK Platform от бизнес-идеи до реализации, тестирования и эксплуатации.

Каждая функция платформы должна иметь возможность быть прослеженной через все уровни проектирования.

---

# Traceability Flow

Business Requirement (BR)

↓

Product Requirement (PR)

↓

Functional Requirement (FR)

↓

User Story (US)

↓

User Journey (UJ)

↓

Screen (SCR)

↓

API

↓

Database

↓

Event (EVT)

↓

Permission (PERM)

↓

Test Case (TEST)

↓

Release

---

# Requirement Types

| Prefix | Description |
|----------|-------------|
| BR | Business Requirement |
| PR | Product Requirement |
| FR | Functional Requirement |
| NFR | Non Functional Requirement |
| US | User Story |
| UJ | User Journey |
| SCR | Screen |
| API | API Endpoint |
| DB | Database Entity |
| EVT | Event |
| PERM | Permission |
| INT | Integration |
| CFG | Configuration |
| JOB | Background Job |
| TEST | Test Case |
| ADR | Architecture Decision |

---

# Example

Business Requirement

BR-001

Customer should be able to order food.

↓

PR-003

Customer App supports online ordering.

↓

FR-012

Create Order.

↓

US-041

As a customer I want to create an order.

↓

UJ-006

Checkout.

↓

SCR-CUS-006

Checkout Screen.

↓

API-018

POST /orders

↓

DB-011

Orders

↓

EVT-004

OrderCreated

↓

TEST-056

Checkout Test

---

# Rules

Every Functional Requirement MUST reference:

- Business Requirement
- Product Requirement

Every Screen MUST reference:

- User Story
- User Journey

Every API MUST reference:

- Functional Requirement

Every Database Entity MUST reference:

- Functional Requirement

Every Test MUST reference:

- Requirement ID

---

# Benefits

Using RTM allows the team to:

- identify impact of changes;
- avoid undocumented functionality;
- ensure complete test coverage;
- improve AI-assisted development;
- simplify maintenance.

---

---

# Related Documents

- PB-305 — PRODUCT REQUIREMENTS
- PB-304 — BUSINESS CAPABILITIES
- API-701 — API OVERVIEW
- DB-601 — DATABASE OVERVIEW
- QA-1301 — TESTING OVERVIEW

---

END OF DOCUMENT