---
Document ID: ARC-510

Document Name: FILE STORAGE

Book: Architecture

Version: 1.0.0

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

# Storage Technology

Primary Storage

- S3 Compatible Object Storage

Supported Providers

- AWS S3
- Cloudflare R2
- MinIO
- DigitalOcean Spaces

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

ARC-511 Search Architecture

END OF DOCUMENT