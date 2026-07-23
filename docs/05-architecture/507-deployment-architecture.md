---
Document ID: ARC-507

Document Name: DEPLOYMENT ARCHITECTURE

Book: Architecture

Version: 1.1.0

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

- Beget Cloud in a Russian region
- Beget Cloud VPS
- Ubuntu LTS
- Docker containers
- Docker Compose
- Nginx
- Beget PostgreSQL DBaaS
- Beget S3
- GitHub Container Registry (GHCR)
- GitHub Actions

Staging and production are isolated environments.

## Target Evolution

Beget Managed Kubernetes is not required for the current stage. It may be introduced when one or more migration criteria are confirmed:

- Docker Compose no longer meets availability or deployment requirements;
- independent service scaling creates material operational pressure;
- multi-node orchestration is required;
- workload isolation requirements increase;
- zero-downtime deployment cannot be achieved reliably with the current model;
- a mature DevOps/SRE operating model is available.

The decision is governed by ADR-1613.

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

ADR-1613 Beget Cloud for MVP and Infrastructure Evolution

ARC-509 Caching Strategy

ARC-514 Security Architecture

END OF DOCUMENT