---
Document ID: ARC-507

Document Name: DEPLOYMENT ARCHITECTURE

Book: Architecture

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# DEPLOYMENT ARCHITECTURE

## Purpose

Определяет архитектуру развертывания SHIK Platform.

---

# Deployment Model

Cloud-Native

Container Based

API-First

Horizontal Scaling Ready

---

# Deployment Stages

## Current Stage — MVP and Early Production

- Google Cloud Platform
- Google Cloud Run
- Managed Cloud Services

## Target Evolution

Kubernetes is not required for the current stage. It may be introduced when one or more migration criteria are confirmed:

- Cloud Run limitations affect product requirements;
- service mesh is required;
- complex workload isolation is required;
- multi-region orchestration is required;
- the number of independently deployed services creates operational pressure;
- a mature DevOps/SRE team is available.

The decision is governed by ADR-1611.

---

# Client Applications

- Customer App
- Back Office
- POS
- Kitchen Display
- Courier App
- Owner Dashboard

---

# Edge Layer

- DNS
- CDN
- Load Balancer
- WAF (Phase 2)

---

# Application Layer

- API Gateway
- Backend API
- Background Workers
- Scheduler

---

# Core Services

- Identity
- Customer
- Restaurant
- Menu
- Orders
- Payments
- Kitchen
- Delivery
- Inventory
- Employees
- Loyalty
- Communication
- Analytics

---

# Infrastructure Services

- PostgreSQL
- Redis
- Object Storage
- Queue
- Secret Manager

---

# External Services

- Payment Providers
- Google Maps
- Яндекс Карты
- 2GIS
- WhatsApp Business
- Telegram
- Email Provider
- SMS Provider
- Push Provider

---

# Deployment Principles

- Stateless Services
- Configuration via Environment Variables
- Immutable Deployments
- Rolling Updates
- Health Checks
- Auto Restart
- Zero Downtime Ready

---

# Scaling

Horizontal

- API
- Workers
- Communication

Vertical

- PostgreSQL
- Redis

---

# Storage

Persistent

- PostgreSQL
- Object Storage

Ephemeral

- Containers
- Cache

---

# Backup Strategy

- Database Daily Backup
- Object Storage Backup
- Configuration Backup
- Secret Backup Policy

---

# Monitoring

- Metrics
- Logs
- Traces
- Alerts
- Uptime Monitoring

---

# Security

- HTTPS Only
- TLS
- Secret Manager
- Network Isolation
- Least Privilege
- Audit Logging

---

# Environments

Development

↓

Testing

↓

Staging

↓

Production

---

# Deployment Pipeline

Developer

↓

GitHub

↓

CI

↓

Tests

↓

Build

↓

Container Registry

↓

CD

↓

Production

---

# Related Documents

ARC-501 System Overview

ARC-508 Technology Stack

ADR-1611 Cloud Run for MVP and Kubernetes Evolution

ARC-509 Caching Strategy

ARC-514 Security Architecture

END OF DOCUMENT