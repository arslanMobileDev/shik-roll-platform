---
Document ID: CMP-1907

Document Name: LEGAL REQUIREMENTS & REGULATORY COMPLIANCE

Book: Compliance & Legal

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: August 2026

Classification: Internal
---

# LEGAL REQUIREMENTS & REGULATORY COMPLIANCE

## Purpose

Определяет юридические требования, нормативные обязательства и правовые принципы, применимые к SHIK Platform.

---

# Objectives

- Legal Compliance
- Regulatory Readiness
- Contract Governance
- Intellectual Property Protection
- Responsible AI Usage

---

# Regulatory Scope

Applies To

- Customers
- Restaurants
- Employees
- Partners
- Vendors
- Third-Party Services
- AI Providers

---

# Applicable Regulations

Current

- Federal Law No. 152-FZ on Personal Data
- Russian personal data localization and operator requirements
- Roskomnadzor notification requirements
- GDPR
- PCI DSS
- Local Labor Laws
- Tax Regulations
- Electronic Commerce Regulations

Future

- ISO 27001
- ISO 22301
- SOC 2
- EU AI Act
- Regional Privacy Regulations

---

# Russian Personal Data Requirements

Before production processing of personal data, the project must:

- document the operator, processing purposes, data categories, data subjects, legal grounds and processing operations;
- map the processing model to Federal Law No. 152-FZ, including Articles 18, 18.1 and 19;
- determine whether notification of Roskomnadzor is required and submit it before processing begins unless legal counsel confirms a specific statutory exception;
- ensure that collection and primary recording of Russian citizens' personal data use databases located in the Russian Federation;
- approve and publish the personal data processing policy and privacy policy;
- approve consent texts, the public offer and withdrawal procedures where applicable;
- define access roles, authentication, audit logging, incident response, retention, correction, blocking and deletion procedures;
- document responsible persons and internal controls;
- complete legal and security review before production launch.

---

# Timeweb Cloud Infrastructure Assessment

Timeweb Cloud confirmed in its written response that:

- services are located in the region selected when they are created;
- the account holder can obtain a certificate of service location;
- the provider supplies infrastructure and platform-level protection;
- the provider does not accept the role of a person processing personal data on the operator's instruction;
- customers independently process their users' personal data;
- support access is limited to critical diagnostics and requires the account owner's permission;
- hosted files, databases and other information are deleted when the agreement terminates without additional warning.

The provider's response is evidence for infrastructure and vendor assessment. It is not a legal clearance for the SHIK Platform processing model and does not transfer the personal data operator's obligations.

Before production, the project must preserve the provider's current offer, policies and written response; obtain the service-location certificate; record the approved service regions; and receive legal confirmation for the final contractual and processing model.

Independent encrypted backups, tested restoration and a provider exit procedure are mandatory because termination can remove hosted data without additional warning.

---

# Contract Management

Supported Agreements

- Master Service Agreement (MSA)
- Service Level Agreement (SLA)
- Data Processing Agreement (DPA)
- Non-Disclosure Agreement (NDA)
- Software License Agreement
- Vendor Agreement

Requirements

- Version Control
- Approval Workflow
- Secure Storage
- Audit Trail

---

# Electronic Documents

Requirements

- Integrity
- Authenticity
- Version History
- Secure Storage
- Access Control

Supported

- PDF
- Digitally Signed Documents
- Audit Records

---

# Intellectual Property

Protect

- Source Code
- Documentation
- Architecture
- APIs
- Database Schema
- Branding
- AI Prompts
- AI Workflows

---

# Open Source Software

Requirements

- Approved Licenses Only
- License Review
- Security Review
- Dependency Tracking
- Attribution Compliance

Preferred Licenses

- MIT
- Apache 2.0
- BSD

Restricted

- GPL Family (Requires Legal Review)

---

# AI Regulatory Compliance

Requirements

- Human Oversight
- Explainability
- Audit Logging
- Prompt Versioning
- Risk Assessment
- Provider Assessment

High Risk AI

Requires

- Human Approval
- Additional Audit
- Risk Review

---

# Records Management

Maintain

- Contracts
- Policies
- Audit Reports
- Compliance Reports
- Risk Assessments
- Security Reviews
- Training Records

Retention

- According To Legal Requirements

---

# Vendor Compliance

Required

- Security Assessment
- Privacy Assessment
- DPA or equivalent contractual assessment where applicable
- SLA Approved
- Periodic Review

---

# Legal Reviews

Required For

- New Third-Party Vendors
- AI Providers
- International Expansion
- Major Architecture Changes
- New Payment Providers

---

# Governance

Responsible Roles

- Product Owner
- Solution Architect
- Security Administrator

Future

- Compliance Officer
- Legal Counsel

---

# Monitoring

Track

- Contract Expiration
- Vendor Reviews
- Regulatory Changes
- License Compliance
- Legal Risks
- AI Compliance

---

# Reporting

Generate

- Compliance Status Report
- Contract Register
- Vendor Compliance Report
- License Compliance Report
- Regulatory Risk Report

---

# Review Schedule

Monthly

- Vendor Review
- License Review

Quarterly

- Regulatory Review
- Contract Review

Annually

- Legal Compliance Assessment
- Policy Update
- Compliance Audit

---

# Related Documents

CMP-1901 Compliance Overview

CMP-1902 GDPR Compliance Specification

CMP-1903 PCI DSS Compliance Specification

CMP-1906 Audit & Compliance Controls

AI-1405 AI Governance & Security

ARC-507 Deployment Architecture

ARC-514 Security Architecture

ADR-1613 Timeweb Cloud MVP Infrastructure

END OF DOCUMENT
