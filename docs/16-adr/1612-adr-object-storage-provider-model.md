---
Document ID: ADR-1612

Document Name: ADR — OBJECT STORAGE PROVIDER MODEL

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: July 2026

Classification: Internal
---

# ADR — OBJECT STORAGE PROVIDER MODEL

## Status

Accepted

---

# Context

SHIK Platform stores product images, brand assets, documents, imports and generated exports.

The documentation currently names Google Cloud Storage, MinIO and S3-compatible object storage without defining whether they are competing standards, environment-specific providers or interchangeable implementations.

The application must support the current Google Cloud deployment while preserving local development, self-hosted and alternative cloud deployment options.

---

# Problem

Direct use of a provider SDK in business logic would create provider coupling.

Google Cloud Storage and S3-compatible providers expose different APIs and must not be represented as the same provider type.

Supporting multiple providers without a common application contract would create inconsistent behavior for uploads, downloads, metadata, signed access and lifecycle operations.

---

# Decision

Use a provider-neutral **Object Storage Port** as the only application-facing storage contract.

Provider SDKs are isolated behind adapters.

Provider allocation:

- Google Cloud Storage with a dedicated GCS Adapter for production in Google Cloud;
- MinIO through the S3-Compatible Adapter for local and development environments;
- S3-compatible providers through the S3 Adapter for alternative cloud or self-hosted deployments.

Google Cloud Storage is not treated as an S3-compatible provider.

---

# Application Contract

The Object Storage Port must define provider-independent operations for:

- upload;
- download;
- delete;
- metadata;
- object existence;
- signed access;
- lifecycle-compatible object classification.

Business and domain logic must not import provider SDKs.

---

# Provider Adapters

## GCS Adapter

- Google Cloud Storage
- Production in Google Cloud
- GCS authentication and signed access semantics

## S3-Compatible Adapter

- MinIO
- AWS S3
- Cloudflare R2
- DigitalOcean Spaces
- Alternative cloud and self-hosted deployments

---

# Environment Allocation

Local

- MinIO

Development

- MinIO by default
- GCS integration environment when required

Staging

- Same provider class as the target production environment

Production in Google Cloud

- Google Cloud Storage

Self-Hosted / Alternative Cloud

- Approved S3-compatible provider

---

# Contract Testing

Every adapter must pass the same contract test suite.

The suite must validate:

- object upload and retrieval;
- metadata handling;
- deletion;
- missing object behavior;
- signed access behavior;
- large object handling;
- retry and error mapping;
- provider-independent application responses.

---

# Consequences

## Positive

- Business logic remains provider-independent.
- Local development does not require access to production cloud storage.
- Google Cloud production remains supported.
- Self-hosted and alternative cloud deployment remain possible.
- Provider migration is isolated to adapter and operational concerns.

## Negative

- Multiple adapters must be implemented and maintained.
- Provider-specific capabilities cannot leak into the common contract.
- Integration and contract testing effort increases.
- Migration between providers still requires data movement planning.

---

# Risks

- Semantic differences between GCS and S3 APIs.
- Inconsistent signed access behavior.
- Provider-specific lifecycle and retention policies.
- Metadata incompatibility.
- Data migration cost and egress charges.

---

# Mitigation

- Keep the Object Storage Port minimal and provider-independent.
- Maintain shared contract tests.
- Document unsupported provider-specific features.
- Keep object keys and metadata portable.
- Test backup and restore per provider.
- Require an architecture review before changing the production provider.

---

# Review Criteria

Review this decision when:

- the production cloud provider changes;
- self-hosted deployment becomes a committed product requirement;
- data residency requirements change;
- storage cost or egress materially changes;
- the common contract cannot support a required capability.

---

# Related Documents

PB-401 System Overview

ARC-508 Technology Stack

ARC-510 File Storage

DB-601 Database Overview

BE-901 Backend Overview

DEV-1201 DevOps Overview

ADR-1611 Cloud Run for MVP and Kubernetes Evolution

END OF DOCUMENT