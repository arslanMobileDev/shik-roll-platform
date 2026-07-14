---
Document ID: DEV-1202

Document Name: REPOSITORY STRUCTURE

Book: DevOps & Infrastructure

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# REPOSITORY STRUCTURE

## Purpose

Определяет структуру Git-репозитория SHIK Platform.

---

# Repository Layout

- apps
- packages
- services
- docs
- infrastructure
- scripts
- tools
- config
- docker
- .github

---

# Applications

- customer-app
- courier-app
- pos
- kitchen
- back-office
- owner-dashboard

---

# Backend Services

- api
- worker
- scheduler

Future

- gateway
- notification-service
- analytics-service

---

# Shared Packages

- ui
- design-system
- api-client
- shared-types
- shared-utils
- config

---

# Infrastructure

- docker
- nginx
- database
- monitoring
- backups

---

# Documentation

Books

- Vision
- Architecture
- Product
- Database
- API
- Frontend
- Backend
- Integrations
- Security
- DevOps

---

# Configuration

- Environment Files
- Docker Configuration
- GitHub Actions
- ESLint
- Prettier
- TypeScript

---

# Naming Convention

Folders

- kebab-case

Files

- kebab-case

Classes

- PascalCase

Variables

- camelCase

Constants

- UPPER_CASE

---

# Repository Rules

- Single Source of Truth
- Modular Structure
- Shared Code
- No Duplicate Logic
- Version Controlled Documentation

---

# Branch Protection

- Protected Main Branch
- Required Pull Request
- Required CI Checks
- Required Code Review

---

# Related Documents

DEV-1201 DevOps Overview

BE-902 Backend Coding Standards

ARC-508 Technology Stack

END OF DOCUMENT