---
Document ID: PERF-2105

Document Name: CACHING STRATEGY

Book: Performance Engineering

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

Определяет стратегию многоуровневого кэширования SHIK Platform для снижения задержек, уменьшения нагрузки на базу данных и повышения масштабируемости платформы.

---

# Objectives

- Reduce Response Time
- Minimize Database Load
- Improve Scalability
- Optimize Resource Utilization
- Increase Cache Efficiency

---

# Caching Principles

- Cache Only What Is Expensive
- Keep Cache Consistent
- Prefer Read Optimization
- Invalidate Predictably
- Monitor Cache Effectiveness
- Fail Gracefully

---

# Cache Layers

Application Cache

- In-Memory Objects
- Configuration
- Feature Flags

Redis Cache

- Sessions
- Frequently Accessed Data
- Rate Limits
- Temporary Objects

HTTP Cache

- REST Responses
- Static Metadata

CDN Cache

- Images
- JavaScript
- CSS
- Fonts
- Public Files

Browser Cache

- Static Assets
- Icons
- Fonts

---

# Redis Usage

Store

- User Sessions
- JWT Blacklists
- OTP Codes
- Rate Limits
- Feature Flags
- Temporary API Responses
- AI Response Cache
- Frequently Accessed Configuration

Never Store

- Passwords
- Encryption Keys
- Payment Credentials
- Long-Term Business Records

---

# Cache Strategies

Primary

- Cache Aside

Supported

- Read Through
- Write Through
- Refresh Ahead (When Justified)

Selection Depends On

- Data Volatility
- Read Frequency
- Consistency Requirements

---

# TTL Guidelines

Very Short

- OTP Codes
- Rate Limits

Recommended TTL

- 1–5 Minutes

Short

- Frequently Updated Data

Recommended TTL

- 5–15 Minutes

Medium

- Menu
- Configuration
- Feature Flags

Recommended TTL

- 30–60 Minutes

Long

- Static Metadata

Recommended TTL

- 24 Hours

---

# Cache Invalidation

Trigger On

- Database Update
- Configuration Change
- User Permission Change
- Menu Update
- Inventory Update
- Feature Flag Update

Methods

- Key Deletion
- Prefix Invalidation
- Event-Driven Invalidation
- TTL Expiration

---

# Cache Key Naming

Format

```
<domain>:<resource>:<identifier>:<version>
```

Examples

```
menu:restaurant:123:v1

user:profile:456:v2

config:features:v1
```

---

# Cache Stampede Prevention

Use

- Distributed Locking
- Request Coalescing
- Randomized TTL
- Background Refresh

---

# Cache Penetration Prevention

Use

- Negative Caching
- Input Validation
- Bloom Filter (Future)
- Rate Limiting

---

# Cache Consistency

Requirements

- Event-Driven Invalidation
- Atomic Updates
- Short TTL For Volatile Data
- Validation Before Critical Operations

---

# AI Cache

Cache

- Prompt Results
- Embeddings
- Model Metadata
- Tool Discovery Results

Do Not Cache

- Sensitive Personal Data
- Payment Information
- Authentication Tokens

---

# Performance Targets

Redis Response

P95

- ≤ 5 ms

Cache Hit Ratio

Target

- ≥ 90%

Application Cache

P95

- ≤ 1 ms

---

# Monitoring

Track

- Cache Hit Ratio
- Cache Miss Ratio
- Eviction Count
- Memory Usage
- Expired Keys
- Keyspace Size
- Response Time

---

# Capacity Management

Monitor

- Memory Utilization
- Key Growth
- Eviction Rate
- TTL Distribution
- Replication Health

---

# Failure Handling

If Cache Is Unavailable

- Continue Using Database
- Log Cache Failure
- Generate Alert
- Recover Automatically

Applications Must Continue Operating Without Cache

---

# Security

Required

- TLS
- Authentication
- Network Isolation
- RBAC
- Audit Logging

---

# Success Metrics

Measure

- Average Response Time
- Cache Hit Ratio
- Database Query Reduction
- Redis Availability
- Memory Efficiency
- Cache Recovery Time

---

# Related Documents

PERF-2101 Performance Engineering Overview

PERF-2102 Scalability Strategy

PERF-2104 Database Performance Optimization

DEV-1205 Docker & Containerization

OPS-1504 Monitoring & Incident Management

END OF DOCUMENT