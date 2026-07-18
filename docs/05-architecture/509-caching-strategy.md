---
Document ID: ARC-509

Document Name: CACHING STRATEGY

Book: Architecture

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# CACHING STRATEGY

## Purpose

Определяет стратегию кеширования SHIK Platform.

---

# Cache Technology

Primary Cache

- Redis

---

# Goals

- Reduce Database Load
- Improve Response Time
- Support High Traffic
- Increase Scalability

---

# Cached Data

## Menu

- Categories
- Products
- Prices
- Modifiers
- Stop List

TTL

- 10 minutes

---

## Restaurant

- Branches
- Working Hours
- Delivery Zones

TTL

- 30 minutes

---

## Configuration

- System Settings
- Feature Flags
- Communication Rules

TTL

- 60 minutes

---

## Customer

- Session
- Profile

TTL

- Session Lifetime

---

## Analytics

- Dashboard Widgets
- KPI

TTL

- 5 minutes

---

# Cache Invalidation

Triggered By

- Product Updated
- Menu Published
- Price Changed
- Stop List Updated
- Branch Updated
- Configuration Changed

---

# Cache Policy

Read

Cache First

Write

Database First

Invalidate Cache

Refresh Cache

---

# Do Not Cache

- Payments
- Passwords
- Tokens
- Audit Log
- Permissions
- Financial Transactions

---

# Redis Usage

- Cache
- Sessions
- Rate Limiting
- Queue Storage
- OTP Codes

---

# Performance Targets

Cache Hit Rate

- ≥90%

Average Cache Response

- <10 ms

---

# Monitoring

- Cache Hit Rate
- Cache Miss Rate
- Memory Usage
- Evictions
- Latency

---

# Related Documents

ARC-507 Deployment Architecture

ARC-508 Technology Stack

ARC-510 File Storage

END OF DOCUMENT