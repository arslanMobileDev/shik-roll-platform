---
Document ID: ARC-508

Document Name: TECHNOLOGY STACK

Book: Architecture

Version: 1.0.0

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

- Google Cloud Storage
- Dedicated GCS Adapter

Local / Development

- MinIO
- S3-Compatible Adapter

Alternative Providers

- S3-compatible object storage
- S3 Adapter

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

Containers

- Docker

Current Runtime

- Google Cloud Run

Orchestration

- Managed by Google Cloud Run

Reverse Proxy

- Nginx (when required)

Environment

- Docker Compose (Development)

---

# CI/CD

Repository

- GitHub

Automation

- GitHub Actions

Deployment

- Google Cloud Run

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

- API First
- Event Driven
- Modular Architecture
- Clean Architecture
- Repository Pattern
- Dependency Injection

---

# Future Technologies

- Kubernetes
- Kafka
- Elasticsearch
- AI Recommendation Engine

---

# Related Documents

ARC-501 System Overview

ARC-503 Microservices Strategy

ARC-507 Deployment Architecture

ADR-1611 Cloud Run for MVP and Kubernetes Evolution

ADR-1612 Object Storage Provider Model

ARC-509 Caching Strategy

END OF DOCUMENT