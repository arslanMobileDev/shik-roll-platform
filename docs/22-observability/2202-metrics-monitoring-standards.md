---
Document ID: OBS-2202

Document Name: METRICS & MONITORING STANDARDS

Book: Observability

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# METRICS & MONITORING STANDARDS

## Purpose

Определяет единые стандарты сбора, хранения, визуализации и анализа метрик для SHIK Platform.

---

# Objectives

- Standardized Metrics
- Actionable Dashboards
- Reliable Alerting
- Capacity Visibility
- Performance Optimization

---

# Monitoring Principles

- Measure What Matters
- Automate Metric Collection
- Standardize Labels
- Avoid High Cardinality
- Monitor Business And Technical Metrics
- Continuously Validate Dashboards

---

# Monitoring Stack

Metrics

- Prometheus

Visualization

- Grafana

Alerting

- Alertmanager

Tracing

- OpenTelemetry

Logging

- Loki

---

# Golden Signals

Latency

Measure

- API Response Time
- Database Query Time
- Queue Processing Time

Traffic

Measure

- Requests Per Second
- Concurrent Users
- Queue Throughput

Errors

Measure

- HTTP 5xx
- HTTP 4xx
- Failed Jobs
- Failed Payments

Saturation

Measure

- CPU
- Memory
- Disk
- Database Connections
- Queue Utilization

---

# RED Method

Rate

- Request Rate

Errors

- Error Rate

Duration

- Request Duration

Applies To

- REST API
- AI Gateway
- Workers
- Internal Services

---

# USE Method

Utilization

- CPU
- Memory
- Disk

Saturation

- Queue Depth
- Database Connections
- Thread Pools

Errors

- Hardware Errors
- Service Errors
- Infrastructure Errors

---

# Business Metrics

Track

- Orders Per Minute
- Revenue
- Active Restaurants
- Active Users
- Payment Success Rate
- Delivery Time
- AI Requests
- Customer Satisfaction

---

# Infrastructure Metrics

Collect

- CPU Usage
- Memory Usage
- Disk Usage
- Disk IOPS
- Network Throughput
- Container Count
- Pod Health (Future)

---

# Database Metrics

Track

- Query Duration
- Active Connections
- Transactions Per Second
- Lock Wait Time
- Deadlocks
- Cache Hit Ratio
- Replication Lag

---

# Redis Metrics

Track

- Memory Usage
- Cache Hit Ratio
- Evictions
- Connected Clients
- Replication Status

---

# RabbitMQ Metrics

Track

- Queue Depth
- Consumer Count
- Publish Rate
- Acknowledgement Rate
- Retry Count
- Dead Letter Queue Size

---

# AI Metrics

Track

- Requests Per Minute
- Tokens Consumed
- Response Time
- Cost Per Request
- Provider Availability
- Cache Hit Ratio

---

# Metric Naming Convention

Format

```
<service>_<resource>_<metric>_<unit>
```

Examples

```
api_requests_total

api_response_duration_ms

database_query_duration_ms

orders_created_total

redis_cache_hit_ratio

ai_tokens_consumed_total
```

---

# Label Standards

Required Labels

- service
- environment
- version
- instance
- region

Optional Labels

- tenant
- endpoint
- provider
- queue

Avoid

- User ID
- Email
- Session ID
- Order ID
- Any High Cardinality Value

---

# Dashboard Standards

Executive

- Business KPIs
- Revenue
- Availability

Operations

- Infrastructure
- Services
- Alerts

Engineering

- API
- Database
- Queues
- Deployments

Security

- Authentication
- Threat Detection
- Access Violations

AI

- Provider Health
- Cost
- Token Usage
- Response Time

---

# Retention Policy

High Resolution Metrics

- 30 Days

Aggregated Metrics

- 1 Year

Business KPIs

- According To Business Reporting Policy

---

# Validation

Review

- Missing Metrics
- Incorrect Labels
- Dashboard Accuracy
- Alert Coverage

Frequency

- Monthly
- Before Major Releases

---

# Success Metrics

Measure

- Metric Coverage
- Dashboard Accuracy
- Alert Precision
- Detection Time
- Performance Visibility
- Monitoring Availability

---

# Related Documents

OBS-2201 Observability Overview

OPS-1504 Monitoring & Incident Management

PERF-2101 Performance Engineering Overview

PERF-2103 Capacity Planning

DEV-1207 Monitoring, Logging & Observability

END OF DOCUMENT