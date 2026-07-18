---
Document ID: ADR-1611

Document Name: ADR — CLOUD RUN FOR MVP AND KUBERNETES EVOLUTION

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

# ADR — CLOUD RUN FOR MVP AND KUBERNETES EVOLUTION

## Status

Accepted

---

# Context

SHIK Platform requires a production runtime for the MVP and early production stages.

The platform must minimize initial operational complexity while preserving an evolution path for independently deployed services, advanced orchestration and multi-region operation.

---

# Problem

The documentation currently describes both Google Cloud Run and Kubernetes as the deployment platform.

Using Kubernetes before its operational capabilities are required would increase infrastructure complexity, support cost and SRE requirements.

Using Cloud Run without explicit migration criteria could create uncertainty about the target architecture.

---

# Decision

Use **Google Cloud Run** as the runtime platform for the MVP and early production stages.

Kubernetes is not required for the current stage. It remains a target evolution option and may be introduced only when confirmed product or operational requirements justify the migration.

---

# Current Stage

- Google Cloud Platform
- Google Cloud Run
- Managed Cloud Services
- GitHub Actions
- Artifact Registry

---

# Kubernetes Migration Criteria

A Kubernetes adoption review is required when one or more criteria are confirmed:

- Cloud Run limitations affect product requirements;
- service mesh is required;
- complex workload isolation is required;
- multi-region orchestration is required;
- the number of independently deployed services creates operational pressure;
- a mature DevOps/SRE team is available.

Meeting a criterion starts an architecture review. It does not automatically approve migration.

---

# Consequences

## Positive

- Lower operational complexity for MVP.
- Faster initial delivery.
- Managed scaling and runtime operations.
- A documented evolution path remains available.
- Kubernetes is introduced only with measurable justification.

## Negative

- Early production depends on Google Cloud services.
- A future Kubernetes migration may require additional engineering.
- Some workloads may require provider-specific design constraints.

---

# Risks

- Vendor dependency.
- Future migration cost.
- Cloud Run runtime limitations.
- Inconsistent infrastructure documentation.

---

# Mitigation

- Keep applications container-based.
- Keep business logic independent from the runtime provider.
- Maintain infrastructure-as-code.
- Review migration criteria during architecture and capacity reviews.
- Document provider-specific constraints.

---

# Review Criteria

Review this decision when:

- Cloud Run limits affect reliability or product requirements;
- multi-region orchestration becomes mandatory;
- independently deployed services materially increase;
- infrastructure cost or compliance requirements change;
- the DevOps/SRE operating model changes.

---

# Related Documents

PB-401 System Overview

ARC-507 Deployment Architecture

ARC-508 Technology Stack

DEV-1201 DevOps Overview

DEV-1204 CI/CD Pipeline Specification

GOV-2704 Technology Lifecycle Management

OBS-2201 Observability Overview

END OF DOCUMENT