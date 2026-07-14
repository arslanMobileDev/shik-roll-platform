---
Document ID: OBS-2203

Document Name: DISTRIBUTED TRACING ARCHITECTURE

Book: Observability

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# DISTRIBUTED TRACING ARCHITECTURE

## Purpose

Определяет архитектуру распределенной трассировки (Distributed Tracing) для SHIK Platform с использованием OpenTelemetry, обеспечивая полную прослеживаемость запросов между сервисами.

---

# Objectives

- End-to-End Request Visibility
- Fast Root Cause Analysis
- Cross-Service Correlation
- Performance Analysis
- Dependency Mapping

---

# Tracing Principles

- Trace Every Critical Request
- Preserve Context Across Services
- Minimize Instrumentation Overhead
- Standardize Trace Metadata
- Correlate Metrics, Logs And Traces

---

# Technology Stack

Instrumentation

- OpenTelemetry SDK

Protocol

- OTLP

Collector

- OpenTelemetry Collector

Tracing Backend

- Jaeger (Future)
- Grafana Tempo (Preferred)

Visualization

- Grafana

---

# Trace Lifecycle

Client Request

↓

API Gateway

↓

Backend Service

↓

Database

↓

Queue

↓

Worker

↓

External API

↓

Response

---

# Trace Context

Every Trace Must Include

- Trace ID
- Span ID
- Parent Span ID
- Correlation ID
- Timestamp
- Service Name
- Environment
- Version

---

# Trace Propagation

Supported Protocols

- HTTP
- HTTPS
- gRPC (Future)
- RabbitMQ
- WebSocket (Future)

Headers

- traceparent
- tracestate
- baggage

---

# Span Types

Server

- Incoming API Requests

Client

- Outgoing API Calls

Database

- SQL Queries

Messaging

- Queue Publish
- Queue Consume

Internal

- Business Logic
- Validation
- AI Processing

---

# Instrumentation Scope

Backend

- NestJS Controllers
- Services
- Repositories
- Middleware

Database

- Prisma ORM
- PostgreSQL

Infrastructure

- Redis
- RabbitMQ
- MinIO

AI

- AI Gateway
- Prompt Engine
- Model Router
- External AI Providers

External Integrations

- Payment Gateway
- Maps API
- Notification Services
- Email Provider

---

# Correlation Standards

Every Request Must Share

- Trace ID
- Correlation ID

Logs Must Include

- Trace ID
- Span ID

Metrics Should Include

- Service
- Environment
- Version

---

# Sampling Strategy

Production

- Parent Based Sampling
- Adaptive Sampling

Development

- 100% Sampling

Testing

- Configurable Sampling

---

# Performance Targets

Tracing Overhead

- ≤ 5%

Trace Collection Success

- ≥ 99%

Trace Availability

- ≥ 99.9%

---

# Sensitive Data

Never Include

- Passwords
- JWT Tokens
- API Keys
- Payment Credentials
- Personal Data
- Secrets

Allowed

- Technical Metadata
- Timing Information
- Resource Names
- Status Codes

---

# Monitoring

Track

- Trace Volume
- Trace Duration
- Sampling Rate
- Export Failures
- Collector Health
- Missing Context

---

# Trace Analysis

Identify

- Slow Requests
- Failed Requests
- Database Bottlenecks
- Queue Delays
- AI Latency
- External API Delays

---

# Dashboard Requirements

Provide

- End-to-End Request Timeline
- Service Dependency Graph
- Slowest Operations
- Error Traces
- AI Processing Timeline
- Database Query Timeline

---

# Future Enhancements

Planned

- Automatic Root Cause Analysis
- AI-Assisted Trace Analysis
- Intelligent Sampling
- Cross-Region Trace Correlation
- Business Transaction Tracing

---

# Success Metrics

Measure

- Trace Coverage
- Mean Trace Duration
- Root Cause Identification Time
- Trace Collection Success Rate
- Performance Bottleneck Detection
- Cross-Service Visibility

---

# Related Documents

OBS-2201 Observability Overview

OBS-2202 Metrics & Monitoring Standards

OPS-1504 Monitoring & Incident Management

PERF-2101 Performance Engineering Overview

AI-1402 AI Gateway Architecture

DEV-1207 Monitoring, Logging & Observability

END OF DOCUMENT