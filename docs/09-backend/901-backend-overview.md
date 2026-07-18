---
Document ID: BE-901

Document Name: BACKEND OVERVIEW

Book: Backend Specification

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# BACKEND OVERVIEW

## Purpose

Определяет архитектуру Backend SHIK Platform.

---

# Technology

Framework

- NestJS

Language

- TypeScript

Runtime

- Node.js LTS

---

# Architecture

- Modular Monolith (Phase 1)
- Event Driven Ready
- Domain Driven Design
- Clean Architecture
- CQRS Ready

---

# Core Modules

- Authentication
- Identity
- Customer
- Restaurant
- Branch
- Menu
- Product
- Order
- Payment
- Kitchen
- Delivery
- Inventory
- Employee
- Loyalty
- Communication
- Analytics
- Settings

---

# Infrastructure

- PostgreSQL
- Redis
- RabbitMQ
- Google Cloud Storage (Production)
- MinIO (Local / Development)
- Elasticsearch (Future)

---

# Communication

Synchronous

- REST API

Asynchronous

- RabbitMQ Events

---

# Security

- JWT
- RBAC
- HTTPS
- Audit Logging
- Rate Limiting

---

# Background Processing

- BullMQ Workers
- Redis-backed Scheduled Jobs
- RabbitMQ Event Handlers

---

# Storage

- PostgreSQL
- Provider-neutral Object Storage Port
- GCS Adapter (Production)
- S3-Compatible Adapter with MinIO (Local / Development)
- Cache

---

# Logging

- Application Logs
- Audit Logs
- Security Logs

---

# Monitoring

- Health Checks
- Metrics
- Tracing
- Alerts

---

# Scalability

- Horizontal Scaling
- Stateless Services
- Queue Processing
- Distributed Cache

---

# Related Documents

ARC-508 Technology Stack

ADR-1612 Object Storage Provider Model

DB-601 Database Overview

API-701 API Overview

END OF DOCUMENT