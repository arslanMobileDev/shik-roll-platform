---
Document ID: ARC-508

Document Name: TECHNOLOGY STACK

Book: Architecture

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# TECHNOLOGY STACK

## Purpose

Определяет официальный стек технологий SHIK Platform.

---

# Frontend

## Customer App

- Flutter

## Courier App

- Flutter

## POS

- Flutter

## Kitchen Display System

- Flutter

## Owner Dashboard

- Flutter Web

## Back Office

- Flutter Web

---

# Backend

Framework

- NestJS

Language

- TypeScript

API

- REST

Background Jobs

- BullMQ
- Redis

Event Bus

- RabbitMQ

Future

- GraphQL (Optional)

---

# Database

Primary Database

- PostgreSQL

Cache

- Redis

Search

- PostgreSQL Full Text Search

Future

- Elasticsearch (Optional)

---

# Storage

Application Contract

- Provider-neutral Object Storage Port

Production

- Beget S3
- S3-Compatible Adapter

Local / Development

- MinIO
- S3-Compatible Adapter

Alternative Providers

- Approved S3-compatible object storage
- S3-Compatible Adapter
- Google Cloud Storage through a dedicated GCS Adapter after a separate architecture decision

Google Cloud Storage is not treated as an S3-compatible provider.

Images

- WebP

Documents

- PDF

Exports

- XLSX
- CSV

---

# Authentication

- JWT
- Refresh Tokens
- OAuth 2.0
- Google Sign-In
- Apple Sign-In
- OTP

---

# Communication

- Firebase Cloud Messaging
- Apple Push Notification Service
- WhatsApp Business API
- Telegram Bot API
- SMTP
- SMS Provider

---

# Maps

Supported Providers

- Google Maps
- Яндекс Карты
- 2GIS

Selection

- Configurable via Back Office

---

# Payments

Supported

- Apple Pay
- Google Pay
- СБП
- CloudPayments
- ЮKassa

Architecture

- Provider Adapter Pattern

---

# Infrastructure

Provider

- Beget Cloud in a Russian region

Containers

- Docker

Current Runtime

- Beget Cloud VPS
- Ubuntu LTS

Orchestration

- Docker Compose

Reverse Proxy

- Nginx

Managed Database

- Beget PostgreSQL DBaaS

Environment

- Docker Compose (Development, Staging and Production)

---

# CI/CD

Repository

- GitHub

Automation

- GitHub Actions

Container Registry

- GitHub Container Registry (GHCR)

Deployment

- Beget Cloud VPS
- Docker Compose

---

# Monitoring

- Prometheus
- Grafana

Logging

- Loki

Tracing

- OpenTelemetry

---

# Testing

Unit

- Jest

Integration

- Supertest

E2E

- Playwright

Flutter

- flutter_test

---

# Code Quality

Formatting

- Prettier

Linting

- ESLint

Flutter Lint

- flutter_lints

Commit Convention

- Conventional Commits

---

# Architecture Rules

- API-First
- Event-Driven
- Modular Architecture
- Clean Architecture
- Repository Pattern
- Dependency Injection

---

# Future Technologies

- Beget Managed Kubernetes
- Kafka
- Elasticsearch
- AI Recommendation Engine

---

# Related Documents

ARC-501 System Overview

ARC-503 Microservices Strategy

ARC-507 Deployment Architecture

ADR-1613 Beget Cloud for MVP and Infrastructure Evolution

ADR-1612 Object Storage Provider Model

ARC-509 Caching Strategy

END OF DOCUMENT