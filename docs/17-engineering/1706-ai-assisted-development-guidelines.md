---
Document ID: ENG-1706

Document Name: AI-ASSISTED DEVELOPMENT GUIDELINES

Book: Engineering Handbook

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# AI-ASSISTED DEVELOPMENT GUIDELINES

## Purpose

Определяет правила безопасного и эффективного использования AI-инструментов при разработке SHIK Platform.

---

# Objectives

- Increase Developer Productivity
- Maintain Code Quality
- Protect Sensitive Information
- Ensure Human Oversight
- Standardize AI Usage

---

# Approved AI Tools

- ChatGPT
- Claude Code
- GitHub Copilot
- MCP Tools
- Internal AI Agents

Future

- Cursor
- Windsurf
- OpenAI Codex

---

# Approved Use Cases

Architecture

- Architecture Review
- ADR Drafting
- Design Discussions

Development

- Code Generation
- Refactoring
- Documentation
- Unit Tests
- API Examples
- SQL Queries

Quality

- Code Review
- Bug Analysis
- Performance Suggestions
- Security Review

Documentation

- Markdown
- OpenAPI
- UML
- Release Notes
- Technical Specifications

---

# Prohibited Usage

Never Send

- Production Secrets
- API Keys
- JWT Tokens
- Database Passwords
- Private Certificates
- Customer Payment Data
- Personally Identifiable Information (PII)
- Production Database Dumps

---

# Prompt Standards

Include

- Goal
- Context
- Constraints
- Expected Output
- Acceptance Criteria

Avoid

- Ambiguous Instructions
- Missing Context
- Sensitive Information

---

# AI Generated Code

Must Be

- Reviewed By Developer
- Tested
- Linted
- Documented
- Architecture Compliant

Never Merge Without

- Human Review
- CI Success
- Security Validation

---

# Code Review

Review

- Business Logic
- Security
- Performance
- Error Handling
- Naming
- Architecture
- Test Coverage

---

# AI Decision Policy

AI May

- Suggest
- Generate
- Explain
- Refactor
- Analyze

AI Must Not

- Approve Pull Requests
- Approve Releases
- Deploy Production
- Change Security Policies
- Execute Financial Operations

---

# MCP Usage

Allowed

- Documentation Search
- Code Search
- API Inspection
- Architecture Lookup
- Test Generation

Restricted

- Production Writes
- Secret Access
- Permission Changes

---

# Prompt Versioning

Track

- Prompt ID
- Version
- Author
- Purpose
- Last Review Date

---

# Security

Required

- Prompt Validation
- Output Validation
- Human Approval
- Audit Logging
- RBAC
- Least Privilege

---

# Quality Gates

AI Generated Code Must Pass

- Build
- Lint
- Unit Tests
- Integration Tests
- Security Scan
- Code Review

---

# Continuous Improvement

Review

- AI Usage Metrics
- Prompt Quality
- Generated Code Quality
- Productivity Gains
- Security Findings

Frequency

- Monthly

---

# Related Documents

AI-1404 Prompt Engineering Specification

AI-1405 AI Governance & Security

AI-1407 MCP & Tool Integration Architecture

QA-1308 Test Automation & Quality Gates

END OF DOCUMENT