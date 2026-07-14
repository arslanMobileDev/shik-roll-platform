---
Document ID: DEV-1203

Document Name: GIT WORKFLOW & BRANCHING STRATEGY

Book: DevOps & Infrastructure

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# GIT WORKFLOW & BRANCHING STRATEGY

## Purpose

Определяет стратегию работы с Git для SHIK Platform.

---

# Repository Strategy

- Monorepo
- GitHub
- Protected Branches
- Pull Request Workflow

---

# Main Branches

- main
- develop

---

# Working Branches

- feature/*
- bugfix/*
- hotfix/*
- release/*
- docs/*
- refactor/*
- chore/*

---

# Branch Naming

Examples

- feature/order-service
- feature/customer-app
- bugfix/payment-timeout
- hotfix/security-fix
- docs/api-update

---

# Commit Convention

Format

```text
type(scope): description
```

Types

- feat
- fix
- docs
- refactor
- test
- build
- ci
- chore

---

# Pull Requests

Required

- CI Passed
- Code Review
- No Merge Conflicts
- Linked Issue
- Updated Documentation

---

# Code Review

Minimum Reviewers

- 2

Checklist

- Architecture
- Security
- Performance
- Readability
- Tests

---

# Merge Strategy

Allowed

- Squash Merge

Not Allowed

- Merge Commit
- Rebase Merge

---

# Release Workflow

feature

↓

develop

↓

release

↓

main

↓

tag

↓

deployment

---

# Tags

Format

- v1.0.0
- v1.1.0
- v2.0.0

---

# Versioning

Standard

- Semantic Versioning

---

# Branch Protection

Required

- Pull Request
- Passing CI
- Required Reviews
- No Force Push
- No Direct Push

---

# Documentation

Required

- ADR Updates
- API Updates
- Changelog
- Release Notes

---

# Related Documents

DEV-1201 DevOps Overview

DEV-1202 Repository Structure

SEC-1107 Secure Development Lifecycle

END OF DOCUMENT