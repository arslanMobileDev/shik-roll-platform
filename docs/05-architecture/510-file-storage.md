---
Document ID: ARC-510

Document Name: FILE STORAGE

Book: Architecture

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# FILE STORAGE

## Purpose

Определяет стратегию хранения файлов SHIK Platform.

---

# Storage Architecture

Application

↓

Object Storage Port

↓

Provider Adapter

↓

Object Storage Provider

---

# Provider Model

## Staging / Production

- Beget S3
- S3-Compatible Adapter

## Local / Development

- MinIO
- S3-Compatible Adapter

## Alternative Providers

- Approved S3-compatible object storage through the S3-Compatible Adapter
- Google Cloud Storage through a dedicated GCS Adapter only after a separate architecture decision

Google Cloud Storage is not treated as an S3-compatible provider and must use a separate adapter.

All adapters must implement the same internal Object Storage Port and pass the same contract tests.

---

# Stored Files

## Product Images

- Main Image
- Gallery Images

Formats

- WebP
- PNG
- JPEG

---

## Restaurant Assets

- Logo
- Cover Image
- Branding

---

## Marketing

- Banners
- Promotions
- Campaign Images

---

## Customer

- Avatar

---

## Documents

- PDF
- CSV
- XLSX

---

# Upload Rules

- Unique Filename
- Virus Scan Ready
- Metadata Stored
- File Validation
- MIME Type Validation

---

# Image Processing

Automatically Generate

- Original
- Large
- Medium
- Thumbnail

Optimization

- WebP Conversion
- Compression
- Resize

---

# Naming Convention

```
{entity}/{entityId}/{uuid}.webp
```

Example

```
products/123/550e8400.webp
```

---

# Security

- Private Storage
- Signed URLs
- Access Control
- HTTPS Only

---

# Retention

Deleted Files

- Soft Delete

Permanent Removal

- Scheduled Cleanup

---

# Performance

- CDN Ready
- Lazy Loading
- Compression
- Browser Cache

---

# Related Documents

ARC-507 Deployment Architecture

ARC-508 Technology Stack

ADR-1612 Object Storage Provider Model

ADR-1613 Beget Cloud for MVP and Infrastructure Evolution

ARC-511 Search Architecture

END OF DOCUMENT