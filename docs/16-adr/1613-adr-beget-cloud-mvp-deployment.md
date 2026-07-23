---
Document ID: ADR-1613

Document Name: ADR — BEGET CLOUD FOR MVP AND INFRASTRUCTURE EVOLUTION

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: July 2026
Last Updated: July 2026

Classification: Internal
---

# ADR — BEGET CLOUD FOR MVP AND INFRASTRUCTURE EVOLUTION

## Status

Accepted

---

# Context

SHIK Platform requires an infrastructure model for MVP and early production that supports Russian data-localization requirements, predictable initial cost and an evolution path for future scaling.

The project owner selected Beget as the infrastructure provider for the current production target.

ADR-1611 previously selected Google Cloud Run for MVP and early production. The provider choice and data-residency requirements have changed, so that decision is superseded by this ADR.

---

# Decision

Use **Beget Cloud in a Russian region** as the infrastructure platform for MVP and early production.

The current production model is:

- Beget Cloud VPS for application runtime;
- Ubuntu LTS as the server operating system;
- Docker containers orchestrated with Docker Compose;
- Nginx as the public reverse proxy and TLS termination layer;
- Beget PostgreSQL DBaaS in the same Russian region;
- private network connectivity and TLS for database access;
- Beget S3 as the production object storage provider through the provider-neutral Object Storage Port and S3-Compatible Adapter;
- Redis, RabbitMQ and BullMQ workers operated as isolated infrastructure services for the MVP;
- separate staging and production environments;
- automated provider backups supplemented by independently verified application backups.

MinIO remains the default object storage provider for local development.

Google Cloud Run, Cloud SQL and Google Cloud Storage are no longer the current production target. Their future use requires a separate architecture and legal review.

---

# Runtime Model

The application remains container-based and provider-portable.

Business and domain logic must not depend on Beget-specific APIs.

Application configuration, secrets, storage access and infrastructure integration must remain isolated behind configuration and provider adapters.

---

# Database Model

PostgreSQL remains the primary database under ADR-1604.

For MVP and early production, PostgreSQL is operated through Beget PostgreSQL DBaaS.

Production database access must:

- use private networking where available;
- require TLS;
- prohibit unnecessary public access;
- use least-privilege credentials;
- maintain tested backup and recovery procedures.

---

# Object Storage Model

ADR-1612 remains the governing provider-neutral storage contract.

Environment allocation is:

- Local and Development — MinIO through the S3-Compatible Adapter;
- Staging — Beget S3;
- Production — Beget S3;
- Alternative deployment — an approved adapter and provider selected through architecture review.

---

# Kubernetes Evolution

Kubernetes is not required for the MVP.

Beget Managed Kubernetes may be reviewed only when one or more criteria are confirmed:

- Docker Compose operations no longer meet availability or deployment requirements;
- independent service scaling creates material operational pressure;
- multi-node orchestration is required;
- workload isolation requirements increase;
- zero-downtime deployment cannot be achieved reliably with the current model;
- a mature DevOps/SRE operating model is available.

Meeting a criterion starts an architecture review and does not automatically approve migration.

---

# Data Residency and Compliance Boundary

Selecting a Russian region supports the project data-localization strategy.

This infrastructure decision does not by itself prove compliance with Federal Law No. 152-FZ. Legal documents, consent flows, operator obligations, access controls, retention, incident response and organizational measures require separate verification.

Personal data must not be transferred to another region or provider without legal and architecture review.

---

# Consequences

## Positive

- Russian production infrastructure aligns with the current data-localization strategy.
- Initial cost and operational scope remain predictable for MVP.
- Docker-based deployment preserves a future migration path.
- Managed PostgreSQL reduces database administration burden.
- The provider-neutral storage contract remains intact.
- Staging and production can use the same storage provider class.

## Negative

- VPS operation requires patching, hardening, monitoring and capacity management.
- Docker Compose does not provide all Kubernetes orchestration capabilities.
- Redis and RabbitMQ operations remain the project team's responsibility for MVP.
- Provider migration requires operational planning and data transfer.
- Independent backups and recovery exercises are still required.

---

# Risks

- Single-node runtime failure.
- Incorrect VPS hardening or secret management.
- Insufficient monitoring or backup verification.
- Capacity exhaustion during demand growth.
- Incorrect assumption that provider selection alone ensures legal compliance.

---

# Mitigation

- Maintain separate staging and production environments.
- Use infrastructure-as-code where practical.
- Apply least privilege, TLS, firewall rules and private networking.
- Monitor capacity, availability, queues and database health.
- Test database and object-storage recovery.
- Keep application containers and provider adapters portable.
- Review Kubernetes criteria during capacity and architecture reviews.
- Perform a dedicated 152-FZ legal and technical compliance review before production launch.

---

# Supersedes

ADR-1611 Cloud Run for MVP and Kubernetes Evolution

---

# Related Documents

ADR-1604 PostgreSQL as Primary Database

ADR-1611 Cloud Run for MVP and Kubernetes Evolution

ADR-1612 Object Storage Provider Model

ARC-507 Deployment Architecture

ARC-508 Technology Stack

ARC-510 File Storage

DEV-1201 DevOps Overview

CMP-1905 Privacy Policy & Data Processing Architecture

END OF DOCUMENT