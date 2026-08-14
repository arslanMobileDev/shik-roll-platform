---
Document ID: ADR-1613

Document Name: ADR — TIMEWEB CLOUD MVP INFRASTRUCTURE

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: August 2026
Last Updated: August 2026

Classification: Internal
---

# ADR — TIMEWEB CLOUD MVP INFRASTRUCTURE

## Status

Accepted

---

# Context

SHIK Platform requires an economically proportionate infrastructure for development, MVP and early production with data localization in the Russian Federation.

The selected provider must support containerized application workloads, a managed PostgreSQL database, queue and cache services, S3-compatible Object Storage, private networking, backups and documented service location.

Timeweb Cloud confirmed that services are created in the selected region and that an account holder can obtain a certificate of service location. The provider also stated that it supplies infrastructure and platform-level protection but does not act as a person processing personal data on the operator's instruction.

---

# Decision

Use **Timeweb Cloud in a Russian region** as the infrastructure provider for development, MVP and early production.

The planned baseline is:

- Ubuntu 24.04 LTS virtual machine;
- Docker and Docker Compose for application deployment;
- managed PostgreSQL 17;
- managed RabbitMQ 4.0;
- managed Valkey 9.1 for cache and BullMQ-compatible workloads;
- Timeweb Cloud Object Storage through the S3-compatible adapter;
- a private network for service-to-service communication;
- public access only through explicitly approved application entry points;
- provider backups plus an independent export and restore procedure.

Exact service sizes are capacity settings, not permanent architecture decisions, and may be adjusted after load testing and monitoring.

---

# Network Boundary

Application services, PostgreSQL, RabbitMQ and Valkey must communicate through a private network.

PostgreSQL, RabbitMQ and Valkey must not receive public IP addresses unless a separately approved operational requirement exists.

Object Storage may use a public endpoint, but objects are private by default and application access uses controlled or signed URLs.

---

# Personal Data and Legal Responsibility

The project owner remains the personal data operator and is responsible for the legal basis, purposes, composition, retention, access and deletion of personal data.

The provider's response is evidence for infrastructure assessment, but it is not a legal clearance for the SHIK Platform processing model and does not transfer operator obligations to the provider.

Before production processing of personal data, the project must:

- confirm that every selected service is located in the Russian Federation and obtain the available location certificate;
- map actual processing operations to Federal Law No. 152-FZ, including Articles 18, 18.1 and 19;
- determine and complete the required Roskomnadzor notification before processing starts, unless legal counsel confirms a specific exception;
- approve the privacy policy, personal data processing policy, consent texts and public offer;
- approve roles, access controls, audit logging, incident response, retention and deletion procedures;
- preserve the provider's current offer, policies and written response in the project legal records;
- obtain legal confirmation that the final service configuration and contractual model are sufficient for production.

The provider stated that support access is limited to critical diagnostics and requires the account owner's permission. Operational procedures must preserve that approval boundary and record any granted access.

---

# Data Exit and Termination

The provider's offer states that files, databases and other hosted information are deleted when the agreement terminates without an additional warning.

Therefore the project must maintain:

- regular database backups;
- Object Storage inventory and export capability;
- encrypted copies outside the primary runtime boundary;
- tested restore procedures;
- an infrastructure exit plan that does not depend on an active provider account.

---

# Kubernetes Evolution

Kubernetes is not required for the MVP or early production baseline.

It remains a conditional option and requires a separate architecture review when operational scale, workload isolation, service orchestration or reliability requirements justify it.

---

# Superseded Decisions

This ADR supersedes ADR-1611 as the current deployment-provider decision.

ADR-1611 remains a historical record of the previously accepted Cloud Run baseline. Its Kubernetes review criteria remain informative and are incorporated into this decision.

Legacy Google Cloud provider references are historical or alternative deployment options and do not describe the current MVP production baseline.

---

# Consequences

## Positive

- Russian-region infrastructure and documented service location.
- Managed database, queue, cache and Object Storage services are available from one provider.
- Lower operational complexity than Kubernetes for the current stage.
- Container-based applications preserve portability.
- Private networking reduces exposure of infrastructure services.

## Negative

- The project assumes responsibility for application, operating-system and access security.
- The provider does not accept the role of processing personal data on the operator's instruction in its response.
- Managed services and provider-specific operations create migration work.
- Production readiness still depends on legal, security, backup and recovery gates.

---

# Review Criteria

Review this decision when:

- the provider's contract, policies or service locations materially change;
- a selected service cannot meet confirmed personal data or security requirements;
- capacity, availability or cost targets are not met;
- Kubernetes migration criteria become applicable;
- another provider is proposed for production;
- independent legal review changes the required contractual or technical model.

---

# Related Documents

ARC-507 Deployment Architecture

ARC-510 File Storage

ARC-514 Security Architecture

CMP-1907 Legal Requirements & Regulatory Compliance

ADR-1611 Cloud Run for MVP and Kubernetes Evolution

ADR-1612 Object Storage Provider Model

DEV-1201 DevOps Overview

BCP-2003 Disaster Recovery Strategy

END OF DOCUMENT
