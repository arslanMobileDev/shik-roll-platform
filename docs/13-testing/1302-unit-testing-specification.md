---
Document ID: QA-1302

Document Name: UNIT TESTING SPECIFICATION

Book: Testing & Quality Assurance

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# UNIT TESTING SPECIFICATION

## Purpose

Определяет стандарты Unit Testing SHIK Platform.

---

# Objectives

- Validate Business Logic
- Fast Feedback
- High Coverage
- Reliable Tests
- Isolated Execution

---

# Scope

Test

- Services
- Utilities
- Validators
- Mappers
- Domain Logic

Do Not Test

- External APIs
- Database
- Message Queue

---

# Framework

- Jest

---

# Test Structure

- Arrange
- Act
- Assert

---

# Naming Convention

Format

should_<expected_result>_when_<condition>

---

# Mocking

Allowed

- Repository
- External API
- Queue
- Cache
- Storage

---

# Coverage

Minimum

- Statements ≥ 90%
- Branches ≥ 90%
- Functions ≥ 90%
- Lines ≥ 90%

---

# Test Rules

- Independent
- Repeatable
- Deterministic
- Fast
- Readable

---

# Assertions

Validate

- Return Values
- Exceptions
- Events
- Side Effects

---

# Execution

Run

- Every Commit
- Pull Request
- CI Pipeline

---

# Reporting

Include

- Coverage
- Passed Tests
- Failed Tests
- Execution Time

---

# Related Documents

QA-1301 Testing Overview

DEV-1204 CI/CD Pipeline Specification

BE-902 Backend Coding Standards

END OF DOCUMENT