---
Document ID: BCP-2002

Document Name: BUSINESS IMPACT ANALYSIS (BIA)

Book: Business Continuity & Disaster Recovery

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# BUSINESS IMPACT ANALYSIS (BIA)

## Purpose

Определяет критичность бизнес-процессов SHIK Platform, их зависимости, допустимое время простоя и приоритеты восстановления.

---

# Objectives

- Identify Critical Business Processes
- Define Recovery Priorities
- Establish RTO & RPO Targets
- Minimize Business Impact
- Support Disaster Recovery Planning

---

# Business Impact Principles

- Customer First
- Financial Protection
- Operational Continuity
- Regulatory Compliance
- Risk-Based Recovery

---

# Criticality Levels

Critical

- Immediate Recovery Required

High

- Recover Within Business Targets

Medium

- Recover After Critical Services

Low

- Recover When Resources Available

---

# Business Process Classification

Priority 1

- Authentication
- Customer Ordering
- Payment Processing
- Kitchen Operations

Priority 2

- Delivery Management
- Inventory Management
- Notifications
- Employee Operations

Priority 3

- Reporting
- Analytics
- AI Services
- Marketing

Priority 4

- Documentation
- Administrative Tools
- Historical Reports

---

# Recovery Objectives

| Business Process | Priority | RTO | RPO |
|------------------|:-------:|----:|----:|
| Authentication | P1 | ≤ 30 Minutes | ≤ 5 Minutes |
| Order Processing | P1 | ≤ 30 Minutes | ≤ 5 Minutes |
| Payment Processing | P1 | ≤ 30 Minutes | ≤ 5 Minutes |
| Kitchen Operations | P1 | ≤ 1 Hour | ≤ 15 Minutes |
| Delivery Management | P2 | ≤ 2 Hours | ≤ 15 Minutes |
| Inventory | P2 | ≤ 4 Hours | ≤ 30 Minutes |
| Reporting | P3 | ≤ 8 Hours | ≤ 1 Hour |
| Analytics | P3 | ≤ 24 Hours | ≤ 4 Hours |
| AI Services | P3 | ≤ 24 Hours | ≤ 4 Hours |

---

# Business Dependencies

Authentication

Depends On

- PostgreSQL
- Redis
- Backend API

Orders

Depends On

- Authentication
- Menu Service
- PostgreSQL
- RabbitMQ

Payments

Depends On

- Payment Provider
- Backend API
- Database
- Network Connectivity

Kitchen

Depends On

- Orders
- Event Bus
- Kitchen Display

Delivery

Depends On

- Orders
- Maps Provider
- Notifications

---

# Impact Assessment

Business Impact

- Revenue Loss
- Customer Dissatisfaction
- Operational Disruption
- Reputation Damage

Technical Impact

- Data Loss
- Service Downtime
- Integration Failure
- Queue Backlog

Regulatory Impact

- GDPR
- PCI DSS
- Contractual Obligations

---

# Recovery Priorities

Restore Order

1. Infrastructure
2. Database
3. Authentication
4. Order Processing
5. Payment Services
6. Kitchen
7. Delivery
8. Notifications
9. Reporting
10. AI Services

---

# Resource Requirements

People

- DevOps Engineer
- Backend Engineer
- Security Administrator
- Technical Lead

Infrastructure

- Backup Environment
- Database Backups
- Object Storage
- Monitoring Platform

---

# Communication Plan

Notify

- Incident Response Team
- Executive Management
- Restaurant Owners
- Customers (If Required)
- Vendors

---

# Risk Assessment

Primary Risks

- Infrastructure Failure
- Database Corruption
- Cloud Provider Outage
- Network Failure
- Cyber Attack
- Human Error

Mitigation

- High Availability
- Automated Backups
- Disaster Recovery Testing
- Multi-Zone Deployment
- Monitoring & Alerting

---

# Review Schedule

Quarterly

- Business Impact Review
- Dependency Validation
- Recovery Objective Review

Annually

- Full BIA Assessment
- Executive Approval

---

# Success Metrics

Track

- RTO Compliance
- RPO Compliance
- Recovery Success Rate
- Business Downtime
- Financial Impact
- Incident Frequency

---

# Related Documents

BCP-2001 Business Continuity Overview

OPS-1504 Monitoring & Incident Management

OPS-1506 Backup & Maintenance Operations

SEC-1108 Incident Response & Disaster Recovery

END OF DOCUMENT