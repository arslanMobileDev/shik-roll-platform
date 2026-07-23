---
Document ID: GOV-2707

Document Name: DOCUMENT REGISTRY

Book: Enterprise Architecture Governance

Version: 1.10.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# DOCUMENT REGISTRY

## Purpose

Предоставляет канонический общий реестр всех управляемых документов SHIK Platform, имеющих Document ID.

Реестр обеспечивает единую точку проверки идентификатора, названия, книги, статуса, версии, даты обновления и пути каждого документа.

---

# Document Boundary

Источником истины для содержания и Front Matter является сам управляемый документ.

GOV-2707:

- отражает метаданные документов;
- не заменяет содержание документов;
- не изменяет статус документа;
- не является реестром архитектурных решений вместо ADR-1600;
- не включает навигационные и служебные файлы без Document ID.

ADR-1600 остается каноническим реестром Architecture Decision Records и содержит специальные правила жизненного цикла ADR.

---

# Maintenance Rules

Реестр обновляется в том же пакете изменений, когда:

- создается новый Document ID;
- изменяется Document Name, Book, Status, Version или Last Updated;
- изменяется путь управляемого документа;
- документ переводится в другой жизненный цикл.

Read-only проверка `scripts/check-doc-terminology.py` должна подтверждать:

- каждый уникальный Document ID присутствует в реестре ровно один раз;
- каждая запись указывает на существующий управляемый документ;
- путь записи совпадает с фактическим путем документа;
- в реестре нет неизвестных или дублирующихся Document ID.

---

# Registry

| Document ID | Document Name | Book | Status | Version | Last Updated | Path |
|---|---|---|---|---|---|---|
| ADR-006 | Unified Communication Automation Center | — | ACCEPTED | 1.0.0 | July 2026 | `docs/03-product/COMMUNICATION_AUTOMATION_CENTER.md` |
| ADR-1600 | ARCHITECTURE DECISION RECORDS INDEX | Enterprise Architecture Decision Records | APPROVED | 1.1.0 | July 2026 | `docs/16-adr/1600-adr-index.md` |
| ADR-1601 | ARCHITECTURE DECISION RECORDS OVERVIEW | Enterprise Architecture Decision Records | APPROVED | 1.0.0 | July 2026 | `docs/16-adr/1601-adr-overview.md` |
| ADR-1602 | ADR — MONOREPO ARCHITECTURE | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1602-adr-monorepo-architecture.md` |
| ADR-1603 | ADR — EVENT-DRIVEN ARCHITECTURE | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1603-adr-event-driven-architecture.md` |
| ADR-1604 | ADR — POSTGRESQL AS PRIMARY DATABASE | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1604-adr-postgresql-primary-database.md` |
| ADR-1605 | ADR — NESTJS AS BACKEND FRAMEWORK | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1605-adr-nestjs-backend-framework.md` |
| ADR-1606 | ADR — FLUTTER AS CROSS-PLATFORM FRAMEWORK | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1606-adr-flutter-cross-platform-framework.md` |
| ADR-1607 | ADR — PRISMA ORM AS DATA ACCESS LAYER | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1607-adr-prisma-orm-data-access-layer.md` |
| ADR-1608 | ADR — CLEAN ARCHITECTURE & MODULAR MONOLITH READY | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1608-adr-clean-architecture-modular-monolith.md` |
| ADR-1609 | ADR — API-FIRST & CONTRACT-FIRST DEVELOPMENT | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1609-adr-api-first-contract-first-development.md` |
| ADR-1610 | ADR — AI-FIRST PLATFORM ARCHITECTURE | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1610-adr-ai-first-platform-architecture.md` |
| ADR-1611 | ADR — CLOUD RUN FOR MVP AND KUBERNETES EVOLUTION | Enterprise Architecture Decision Records | SUPERSEDED | 1.1.0 | July 2026 | `docs/16-adr/1611-adr-cloud-run-mvp-kubernetes-evolution.md` |
| ADR-1612 | ADR — OBJECT STORAGE PROVIDER MODEL | Enterprise Architecture Decision Records | ACCEPTED | 1.1.0 | July 2026 | `docs/16-adr/1612-adr-object-storage-provider-model.md` |
| ADR-1613 | ADR — BEGET CLOUD FOR MVP AND INFRASTRUCTURE EVOLUTION | Enterprise Architecture Decision Records | ACCEPTED | 1.0.0 | July 2026 | `docs/16-adr/1613-adr-beget-cloud-mvp-deployment.md` |
| AI-1401 | AI & AUTOMATION OVERVIEW | AI & Automation Specification | APPROVED | 1.0.0 | July 2026 | `docs/14-ai/1401-ai-automation-overview.md` |
| AI-1402 | AI GATEWAY ARCHITECTURE | AI & Automation Specification | APPROVED | 1.0.0 | July 2026 | `docs/14-ai/1402-ai-gateway-architecture.md` |
| AI-1403 | AI AGENTS ARCHITECTURE | AI & Automation Specification | APPROVED | 1.0.0 | July 2026 | `docs/14-ai/1403-ai-agents-architecture.md` |
| AI-1404 | PROMPT ENGINEERING SPECIFICATION | AI & Automation Specification | APPROVED | 1.0.0 | July 2026 | `docs/14-ai/1404-prompt-engineering-specification.md` |
| AI-1405 | AI GOVERNANCE & SECURITY | AI & Automation Specification | APPROVED | 1.0.0 | July 2026 | `docs/14-ai/1405-ai-governance-security.md` |
| AI-1406 | AI WORKFLOWS & BUSINESS AUTOMATION | AI & Automation Specification | APPROVED | 1.0.0 | July 2026 | `docs/14-ai/1406-ai-workflows-business-automation.md` |
| AI-1407 | MCP & TOOL INTEGRATION ARCHITECTURE | AI & Automation Specification | APPROVED | 1.0.0 | July 2026 | `docs/14-ai/1407-mcp-tool-integration-architecture.md` |
| API-701 | API OVERVIEW | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/701-api-overview.md` |
| API-702 | API STANDARDS | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/702-api-standards.md` |
| API-703 | AUTHENTICATION API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/703-authentication-api.md` |
| API-704 | CUSTOMER API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/704-customer-api.md` |
| API-705 | RESTAURANT & BRANCH API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/705-restaurant-branch-api.md` |
| API-706 | MENU & PRODUCT API | API Specification | APPROVED | 1.2.0 | July 2026 | `docs/07-api/706-menu-product-api.md` |
| API-707 | ORDER API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/707-order-api.md` |
| API-708 | PAYMENT API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/708-payment-api.md` |
| API-709 | KITCHEN API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/709-kitchen-api.md` |
| API-710 | DELIVERY API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/710-delivery-api.md` |
| API-711 | INVENTORY API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/711-inventory-api.md` |
| API-712 | EMPLOYEE API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/712-employee-api.md` |
| API-713 | LOYALTY & PROMOTIONS API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/713-loyalty-promotions-api.md` |
| API-714 | COMMUNICATION API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/714-communication-api.md` |
| API-715 | ANALYTICS & REPORTING API | API Specification | APPROVED | 1.0.0 | July 2026 | `docs/07-api/715-analytics-reporting-api.md` |
| ARC-501 | SYSTEM OVERVIEW | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/501-system-overview.md` |
| ARC-502 | MODULAR ARCHITECTURE | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/502-modular-architecture.md` |
| ARC-503 | MICROSERVICES STRATEGY | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/503-microservices.md` |
| ARC-504 | EVENT-DRIVEN ARCHITECTURE | Architecture | APPROVED | 1.2.0 | July 2026 | `docs/05-architecture/504-event-driven-architecture.md` |
| ARC-505 | DOMAIN MODEL | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/505-domain-model.md` |
| ARC-506 | MODULE INTERACTIONS | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/506-module-interactions.md` |
| ARC-507 | DEPLOYMENT ARCHITECTURE | Architecture | APPROVED | 1.1.0 | July 2026 | `docs/05-architecture/507-deployment-architecture.md` |
| ARC-508 | TECHNOLOGY STACK | Architecture | APPROVED | 1.1.0 | July 2026 | `docs/05-architecture/508-technology-stack.md` |
| ARC-509 | CACHING STRATEGY | Architecture | APPROVED | 1.1.0 | July 2026 | `docs/05-architecture/509-caching-strategy.md` |
| ARC-510 | FILE STORAGE | Architecture | APPROVED | 1.1.0 | July 2026 | `docs/05-architecture/510-file-storage.md` |
| ARC-511 | SEARCH ARCHITECTURE | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/511-search-architecture.md` |
| ARC-512 | BACKGROUND JOBS | Architecture | APPROVED | 1.1.0 | July 2026 | `docs/05-architecture/512-background-jobs.md` |
| ARC-513 | COMMUNICATION ARCHITECTURE | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/513-communication-architecture.md` |
| ARC-514 | SECURITY ARCHITECTURE | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/514-security-architecture.md` |
| ARC-515 | HIGH AVAILABILITY & DISASTER RECOVERY | Architecture | APPROVED | 1.0.0 | July 2026 | `docs/05-architecture/515-high-availability.md` |
| BCP-2001 | BUSINESS CONTINUITY OVERVIEW | Business Continuity & Disaster Recovery | APPROVED | 1.0.0 | July 2026 | `docs/20-business-continuity/2001-business-continuity-overview.md` |
| BCP-2002 | BUSINESS IMPACT ANALYSIS (BIA) | Business Continuity & Disaster Recovery | APPROVED | 1.0.0 | July 2026 | `docs/20-business-continuity/2002-business-impact-analysis.md` |
| BCP-2003 | DISASTER RECOVERY STRATEGY | Business Continuity & Disaster Recovery | APPROVED | 1.0.0 | July 2026 | `docs/20-business-continuity/2003-disaster-recovery-strategy.md` |
| BCP-2004 | HIGH AVAILABILITY ARCHITECTURE | Business Continuity & Disaster Recovery | APPROVED | 1.1.0 | July 2026 | `docs/20-business-continuity/2004-high-availability-architecture.md` |
| BCP-2005 | FAILOVER & RECOVERY PROCEDURES | Business Continuity & Disaster Recovery | APPROVED | 1.1.0 | July 2026 | `docs/20-business-continuity/2005-failover-recovery-procedures.md` |
| BCP-2006 | EMERGENCY OPERATIONS & CRISIS MANAGEMENT | Business Continuity & Disaster Recovery | APPROVED | 1.0.0 | July 2026 | `docs/20-business-continuity/2006-emergency-operations-crisis-management.md` |
| BCP-2007 | REGIONAL OUTAGE & MULTI-REGION RECOVERY STRATEGY | Business Continuity & Disaster Recovery | APPROVED | 1.1.0 | July 2026 | `docs/20-business-continuity/2007-regional-outage-multi-region-recovery-strategy.md` |
| BE-901 | BACKEND OVERVIEW | Backend Specification | APPROVED | 1.1.0 | July 2026 | `docs/09-backend/901-backend-overview.md` |
| BE-902 | BACKEND CODING STANDARDS | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/902-backend-coding-standards.md` |
| BE-903 | AUTHENTICATION SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/903-authentication-service.md` |
| BE-904 | CUSTOMER SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/904-customer-service.md` |
| BE-905 | RESTAURANT & BRANCH SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/905-restaurant-branch-service.md` |
| BE-906 | MENU & PRODUCT SERVICE | Backend Specification | APPROVED | 1.2.0 | July 2026 | `docs/09-backend/906-menu-product-service.md` |
| BE-907 | ORDER SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/907-order-service.md` |
| BE-908 | PAYMENT SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/908-payment-service.md` |
| BE-909 | KITCHEN SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/909-kitchen-service.md` |
| BE-910 | DELIVERY SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/910-delivery-service.md` |
| BE-911 | INVENTORY SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/911-inventory-service.md` |
| BE-912 | EMPLOYEE SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/912-employee-service.md` |
| BE-913 | LOYALTY & PROMOTIONS SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/913-loyalty-promotions-service.md` |
| BE-914 | COMMUNICATION SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/914-communication-service.md` |
| BE-915 | ANALYTICS SERVICE | Backend Specification | APPROVED | 1.0.0 | July 2026 | `docs/09-backend/915-analytics-service.md` |
| CMP-1901 | COMPLIANCE OVERVIEW | Compliance & Legal | APPROVED | 1.0.0 | July 2026 | `docs/19-compliance/1901-compliance-overview.md` |
| CMP-1902 | GDPR COMPLIANCE SPECIFICATION | Compliance & Legal | APPROVED | 1.0.0 | July 2026 | `docs/19-compliance/1902-gdpr-compliance-specification.md` |
| CMP-1903 | PCI DSS COMPLIANCE SPECIFICATION | Compliance & Legal | APPROVED | 1.0.0 | July 2026 | `docs/19-compliance/1903-pci-dss-compliance-specification.md` |
| CMP-1904 | DATA RETENTION & DATA LIFECYCLE POLICY | Compliance & Legal | APPROVED | 1.0.0 | July 2026 | `docs/19-compliance/1904-data-retention-data-lifecycle-policy.md` |
| CMP-1905 | PRIVACY POLICY & DATA PROCESSING ARCHITECTURE | Compliance & Legal | APPROVED | 1.1.0 | July 2026 | `docs/19-compliance/1905-privacy-policy-data-processing-architecture.md` |
| CMP-1906 | AUDIT & COMPLIANCE CONTROLS | Compliance & Legal | APPROVED | 1.0.0 | July 2026 | `docs/19-compliance/1906-audit-compliance-controls.md` |
| CMP-1907 | LEGAL REQUIREMENTS & REGULATORY COMPLIANCE | Compliance & Legal | APPROVED | 1.0.0 | July 2026 | `docs/19-compliance/1907-legal-requirements-regulatory-compliance.md` |
| DATA-2301 | ENTERPRISE DATA PLATFORM OVERVIEW | Enterprise Data Platform | APPROVED | 1.1.0 | July 2026 | `docs/23-enterprise-data-platform/2301-enterprise-data-platform-overview.md` |
| DATA-2302 | BUSINESS INTELLIGENCE ARCHITECTURE | Enterprise Data Platform | APPROVED | 1.0.0 | July 2026 | `docs/23-enterprise-data-platform/2302-business-intelligence-architecture.md` |
| DATA-2303 | DATA WAREHOUSE ARCHITECTURE | Enterprise Data Platform | APPROVED | 1.0.0 | July 2026 | `docs/23-enterprise-data-platform/2303-data-warehouse-architecture.md` |
| DATA-2304 | EVENT ANALYTICS & REAL-TIME PROCESSING | Enterprise Data Platform | APPROVED | 1.0.0 | July 2026 | `docs/23-enterprise-data-platform/2304-event-analytics-real-time-processing.md` |
| DATA-2305 | MACHINE LEARNING DATA PIPELINE | Enterprise Data Platform | APPROVED | 1.0.0 | July 2026 | `docs/23-enterprise-data-platform/2305-machine-learning-data-pipeline.md` |
| DATA-2306 | REPORTING & DECISION SUPPORT STRATEGY | Enterprise Data Platform | APPROVED | 1.0.0 | July 2026 | `docs/23-enterprise-data-platform/2306-reporting-decision-support-strategy.md` |
| DB-601 | DATABASE OVERVIEW | Database | APPROVED | 1.1.0 | July 2026 | `docs/06-database/601-database-overview.md` |
| DB-602 | DATABASE STANDARDS | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/602-database-standards.md` |
| DB-603 | ENTITY RELATIONSHIP MODEL | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/603-entity-relationship-model.md` |
| DB-604 | IDENTITY SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/604-identity-schema.md` |
| DB-605 | CUSTOMER SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/605-customer-schema.md` |
| DB-606 | RESTAURANT & BRANCH SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/606-restaurant-branch-schema.md` |
| DB-607 | MENU & PRODUCT SCHEMA | Database | APPROVED | 1.2.0 | July 2026 | `docs/06-database/607-menu-product-schema.md` |
| DB-608 | ORDER SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/608-order-schema.md` |
| DB-609 | PAYMENT SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/609-payment-schema.md` |
| DB-610 | KITCHEN & PRODUCTION SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/610-kitchen-production-schema.md` |
| DB-611 | INVENTORY & WAREHOUSE SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/611-inventory-warehouse-schema.md` |
| DB-612 | EMPLOYEE & ACCESS SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/612-employee-access-schema.md` |
| DB-613 | LOYALTY & PROMOTIONS SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/613-loyalty-promotions-schema.md` |
| DB-614 | COMMUNICATION SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/614-communication-schema.md` |
| DB-615 | ANALYTICS & AUDIT SCHEMA | Database | APPROVED | 1.0.0 | July 2026 | `docs/06-database/615-analytics-audit-schema.md` |
| DEV-1201 | DEVOPS OVERVIEW | DevOps & Infrastructure | APPROVED | 1.1.0 | July 2026 | `docs/12-devops/1201-devops-overview.md` |
| DEV-1202 | REPOSITORY STRUCTURE | DevOps & Infrastructure | APPROVED | 1.0.0 | July 2026 | `docs/12-devops/1202-repository-structure.md` |
| DEV-1203 | GIT WORKFLOW & BRANCHING STRATEGY | DevOps & Infrastructure | APPROVED | 1.0.0 | July 2026 | `docs/12-devops/1203-git-workflow-branching-strategy.md` |
| DEV-1204 | CI/CD PIPELINE SPECIFICATION | DevOps & Infrastructure | APPROVED | 1.1.0 | July 2026 | `docs/12-devops/1204-cicd-pipeline-specification.md` |
| DEV-1205 | DOCKER & CONTAINERIZATION | DevOps & Infrastructure | APPROVED | 1.0.0 | July 2026 | `docs/12-devops/1205-docker-containerization.md` |
| DEV-1206 | ENVIRONMENT CONFIGURATION & SECRETS MANAGEMENT | DevOps & Infrastructure | APPROVED | 1.0.0 | July 2026 | `docs/12-devops/1206-environment-configuration-secrets-management.md` |
| DEV-1207 | MONITORING, LOGGING & OBSERVABILITY | DevOps & Infrastructure | APPROVED | 1.0.0 | July 2026 | `docs/12-devops/1207-monitoring-logging-observability.md` |
| DEV-1208 | DEPLOYMENT & RELEASE MANAGEMENT | DevOps & Infrastructure | APPROVED | 1.0.0 | July 2026 | `docs/12-devops/1208-deployment-release-management.md` |
| ENG-1701 | ENGINEERING HANDBOOK OVERVIEW | Engineering Handbook | APPROVED | 1.0.0 | July 2026 | `docs/17-engineering/1701-engineering-handbook-overview.md` |
| ENG-1702 | DEVELOPER ONBOARDING GUIDE | Engineering Handbook | APPROVED | 1.0.0 | July 2026 | `docs/17-engineering/1702-developer-onboarding-guide.md` |
| ENG-1703 | LOCAL DEVELOPMENT ENVIRONMENT SETUP | Engineering Handbook | APPROVED | 1.0.0 | July 2026 | `docs/17-engineering/1703-local-development-environment-setup.md` |
| ENG-1704 | DEVELOPMENT WORKFLOW & BEST PRACTICES | Engineering Handbook | APPROVED | 1.0.0 | July 2026 | `docs/17-engineering/1704-development-workflow-best-practices.md` |
| ENG-1705 | CODE REVIEW & PULL REQUEST GUIDELINES | Engineering Handbook | APPROVED | 1.0.0 | July 2026 | `docs/17-engineering/1705-code-review-pull-request-guidelines.md` |
| ENG-1706 | AI-ASSISTED DEVELOPMENT GUIDELINES | Engineering Handbook | APPROVED | 1.0.0 | July 2026 | `docs/17-engineering/1706-ai-assisted-development-guidelines.md` |
| ENG-1707 | PRODUCTION READINESS CHECKLIST | Engineering Handbook | APPROVED | 1.0.0 | July 2026 | `docs/17-engineering/1707-production-readiness-checklist.md` |
| GOV-2701 | ENTERPRISE ARCHITECTURE GOVERNANCE OVERVIEW | Enterprise Architecture Governance | APPROVED | 1.0.0 | July 2026 | `docs/27-enterprise-architecture-governance/2701-enterprise-architecture-governance-overview.md` |
| GOV-2702 | ARCHITECTURE REVIEW BOARD (ARB) | Enterprise Architecture Governance | APPROVED | 1.0.0 | July 2026 | `docs/27-enterprise-architecture-governance/2702-architecture-review-board.md` |
| GOV-2703 | ARCHITECTURE DECISION RECORDS (ADR) GOVERNANCE | Enterprise Architecture Governance | APPROVED | 1.0.0 | July 2026 | `docs/27-enterprise-architecture-governance/2703-architecture-decision-records-governance.md` |
| GOV-2704 | TECHNOLOGY LIFECYCLE MANAGEMENT | Enterprise Architecture Governance | APPROVED | 1.1.0 | July 2026 | `docs/27-enterprise-architecture-governance/2704-technology-lifecycle-management.md` |
| GOV-2705 | TECHNICAL DEBT MANAGEMENT | Enterprise Architecture Governance | APPROVED | 1.0.0 | July 2026 | `docs/27-enterprise-architecture-governance/2705-technical-debt-management.md` |
| GOV-2706 | ENTERPRISE ARCHITECTURE ROADMAP | Enterprise Architecture Governance | APPROVED | 1.0.0 | July 2026 | `docs/27-enterprise-architecture-governance/2706-enterprise-architecture-roadmap.md` |
| GOV-2707 | DOCUMENT REGISTRY | Enterprise Architecture Governance | APPROVED | 1.10.0 | July 2026 | `docs/27-enterprise-architecture-governance/2707-document-registry.md` |
| INT-1001 | INTEGRATION OVERVIEW | Integration Specification | APPROVED | 1.0.0 | July 2026 | `docs/10-integrations/1001-integration-overview.md` |
| INT-1002 | PAYMENT GATEWAY INTEGRATIONS | Integration Specification | APPROVED | 1.0.0 | July 2026 | `docs/10-integrations/1002-payment-gateway-integrations.md` |
| INT-1003 | MAPS & GEOLOCATION INTEGRATIONS | Integration Specification | APPROVED | 1.0.0 | July 2026 | `docs/10-integrations/1003-maps-geolocation-integrations.md` |
| INT-1004 | COMMUNICATION PROVIDER INTEGRATIONS | Integration Specification | APPROVED | 1.0.0 | July 2026 | `docs/10-integrations/1004-communication-provider-integrations.md` |
| INT-1005 | ERP & CRM INTEGRATIONS | Integration Specification | APPROVED | 1.0.0 | July 2026 | `docs/10-integrations/1005-erp-crm-integrations.md` |
| INT-1006 | AI & EXTERNAL SERVICES INTEGRATIONS | Integration Specification | APPROVED | 1.0.0 | July 2026 | `docs/10-integrations/1006-ai-external-services-integrations.md` |
| INT-1007 | INTEGRATION SECURITY & MONITORING | Integration Specification | APPROVED | 1.0.0 | July 2026 | `docs/10-integrations/1007-integration-security-monitoring.md` |
| MKT-2501 | MARKETPLACE OVERVIEW | Marketplace & Extensions | APPROVED | 1.0.0 | July 2026 | `docs/25-marketplace/2501-marketplace-overview.md` |
| MKT-2502 | EXTENSION CATALOG ARCHITECTURE | Marketplace & Extensions | APPROVED | 1.0.0 | July 2026 | `docs/25-marketplace/2502-extension-catalog-architecture.md` |
| MKT-2503 | PLUGIN DISTRIBUTION & PUBLISHING | Marketplace & Extensions | APPROVED | 1.0.0 | July 2026 | `docs/25-marketplace/2503-plugin-distribution-publishing.md` |
| MKT-2504 | THIRD-PARTY APPLICATION INTEGRATION | Marketplace & Extensions | APPROVED | 1.0.0 | July 2026 | `docs/25-marketplace/2504-third-party-application-integration.md` |
| MKT-2505 | CERTIFICATION & SECURITY REVIEW | Marketplace & Extensions | APPROVED | 1.0.0 | July 2026 | `docs/25-marketplace/2505-certification-security-review.md` |
| OBS-2201 | OBSERVABILITY OVERVIEW | Observability | APPROVED | 1.0.0 | July 2026 | `docs/22-observability/2201-observability-overview.md` |
| OBS-2202 | METRICS & MONITORING STANDARDS | Observability | APPROVED | 1.0.0 | July 2026 | `docs/22-observability/2202-metrics-monitoring-standards.md` |
| OBS-2203 | DISTRIBUTED TRACING ARCHITECTURE | Observability | APPROVED | 1.0.0 | July 2026 | `docs/22-observability/2203-distributed-tracing-architecture.md` |
| OBS-2204 | LOGGING STANDARDS | Observability | APPROVED | 1.0.0 | July 2026 | `docs/22-observability/2204-logging-standards.md` |
| OBS-2205 | SLI, SLO & SLA MANAGEMENT | Observability | APPROVED | 1.0.0 | July 2026 | `docs/22-observability/2205-sli-slo-sla-management.md` |
| OBS-2206 | ALERTING & INCIDENT DETECTION STRATEGY | Observability | APPROVED | 1.0.0 | July 2026 | `docs/22-observability/2206-alerting-incident-detection-strategy.md` |
| OPS-1501 | OPERATIONS OVERVIEW | Operations & Support Specification | APPROVED | 1.0.0 | July 2026 | `docs/15-operations/1501-operations-overview.md` |
| OPS-1502 | SYSTEM ADMINISTRATION | Operations & Support Specification | APPROVED | 1.0.0 | July 2026 | `docs/15-operations/1502-system-administration.md` |
| OPS-1503 | USER ADMINISTRATION | Operations & Support Specification | APPROVED | 1.0.0 | July 2026 | `docs/15-operations/1503-user-administration.md` |
| OPS-1504 | MONITORING & INCIDENT MANAGEMENT | Operations & Support Specification | APPROVED | 1.0.0 | July 2026 | `docs/15-operations/1504-monitoring-incident-management.md` |
| OPS-1505 | CHANGE & RELEASE OPERATIONS | Operations & Support Specification | APPROVED | 1.0.0 | July 2026 | `docs/15-operations/1505-change-release-operations.md` |
| OPS-1506 | BACKUP & MAINTENANCE OPERATIONS | Operations & Support Specification | APPROVED | 1.0.0 | July 2026 | `docs/15-operations/1506-backup-maintenance-operations.md` |
| OPS-1507 | SERVICE DESK & SLA MANAGEMENT | Operations & Support Specification | APPROVED | 1.0.0 | July 2026 | `docs/15-operations/1507-service-desk-sla-management.md` |
| OPS-2601 | ENTERPRISE OPERATIONS OVERVIEW | Enterprise Operations | APPROVED | 1.0.0 | July 2026 | `docs/26-enterprise-operations/2601-enterprise-operations-overview.md` |
| OPS-2602 | SERVICE MANAGEMENT | Enterprise Operations | APPROVED | 1.0.0 | July 2026 | `docs/26-enterprise-operations/2602-service-management.md` |
| OPS-2603 | CHANGE & RELEASE MANAGEMENT | Enterprise Operations | APPROVED | 1.0.0 | July 2026 | `docs/26-enterprise-operations/2603-change-release-management.md` |
| OPS-2604 | OPERATIONAL READINESS | Enterprise Operations | APPROVED | 1.0.0 | July 2026 | `docs/26-enterprise-operations/2604-operational-readiness.md` |
| OPS-2605 | CAPACITY & COST OPTIMIZATION | Enterprise Operations | APPROVED | 1.0.0 | July 2026 | `docs/26-enterprise-operations/2605-capacity-cost-optimization.md` |
| OPS-2606 | OPERATIONAL EXCELLENCE FRAMEWORK | Enterprise Operations | APPROVED | 1.0.0 | July 2026 | `docs/26-enterprise-operations/2606-operational-excellence-framework.md` |
| PB-001 | PROJECT MANIFEST | — | APPROVED | 1.1.0 | July 2026 | `PROJECT_MANIFEST.md` |
| PB-002 | PROJECT BIBLE | Foundation | APPROVED | 2.1.0 | July 2026 | `PROJECT_BIBLE.md` |
| PB-101 | BUSINESS VISION | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/BUSINESS_VISION.md` |
| PB-102 | PRODUCT VISION | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/PRODUCT_VISION.md` |
| PB-103 | MISSION | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/MISSION.md` |
| PB-104 | BUSINESS GOALS | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/BUSINESS_GOALS.md` |
| PB-105 | BUSINESS MODEL | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/BUSINESS_MODEL.md` |
| PB-106 | STAKEHOLDERS | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/STAKEHOLDERS.md` |
| PB-107 | SUCCESS METRICS | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/SUCCESS_METRICS.md` |
| PB-108 | BUSINESS RULES | Business | APPROVED | 1.0.0 | July 2026 | `docs/01-business/BUSINESS_RULES.md` |
| PB-109 | TERMINOLOGY GLOSSARY | Business | APPROVED | 1.1.0 | July 2026 | `docs/01-business/TERMINOLOGY_GLOSSARY.md` |
| PB-300 | PRODUCT PRINCIPLES | Product | APPROVED | 1.0.0 | July 2026 | `docs/03-product/PRODUCT_PRINCIPLES.md` |
| PB-301 | PRODUCT OVERVIEW | Product | APPROVED | 1.2.0 | July 2026 | `docs/03-product/PRODUCT_OVERVIEW.md` |
| PB-302 | USER PERSONAS | Product | APPROVED | 1.0.0 | July 2026 | `docs/03-product/USER_PERSONAS.md` |
| PB-303 | USER JOURNEYS | Product | APPROVED | 1.1.0 | July 2026 | `docs/03-product/USER_JOURNEYS.md` |
| PB-304 | BUSINESS CAPABILITIES | Product | APPROVED | 1.1.0 | July 2026 | `docs/03-product/BUSINESS_CAPABILITIES.md` |
| PB-305 | PRODUCT REQUIREMENTS | Product | APPROVED | 1.1.0 | July 2026 | `docs/03-product/PRODUCT_REQUIREMENTS.md` |
| PB-306 | COMMUNICATION AUTOMATION CENTER | Product | APPROVED | 1.0.0 | July 2026 | `docs/03-product/306-communication-automation-center.md` |
| PB-401 | PLATFORM OVERVIEW | Architecture | APPROVED | 1.1.0 | July 2026 | `docs/07-architecture/SYSTEM_OVERVIEW.md` |
| PERF-2101 | PERFORMANCE ENGINEERING OVERVIEW | Performance Engineering | APPROVED | 1.0.0 | July 2026 | `docs/21-performance/2101-performance-engineering-overview.md` |
| PERF-2102 | SCALABILITY STRATEGY | Performance Engineering | APPROVED | 1.1.0 | July 2026 | `docs/21-performance/2102-scalability-strategy.md` |
| PERF-2103 | CAPACITY PLANNING | Performance Engineering | APPROVED | 1.0.0 | July 2026 | `docs/21-performance/2103-capacity-planning.md` |
| PERF-2104 | DATABASE PERFORMANCE OPTIMIZATION | Performance Engineering | APPROVED | 1.0.0 | July 2026 | `docs/21-performance/2104-database-performance-optimization.md` |
| PERF-2105 | CACHING STRATEGY | Performance Engineering | APPROVED | 1.0.0 | July 2026 | `docs/21-performance/2105-caching-strategy.md` |
| PERF-2106 | CDN & CONTENT DELIVERY STRATEGY | Performance Engineering | APPROVED | 1.0.0 | July 2026 | `docs/21-performance/2106-cdn-content-delivery-strategy.md` |
| PERF-2107 | LOAD BALANCING & TRAFFIC DISTRIBUTION | Performance Engineering | APPROVED | 1.0.0 | July 2026 | `docs/21-performance/2107-load-balancing-traffic-distribution.md` |
| PM-1801 | PROJECT MANAGEMENT OVERVIEW | Project Management & Delivery | APPROVED | 1.1.0 | July 2026 | `docs/18-project-management/1801-project-management-overview.md` |
| PM-1802 | PRODUCT ROADMAP & RELEASE PLANNING | Project Management & Delivery | APPROVED | 1.1.0 | July 2026 | `docs/18-project-management/1802-product-roadmap-release-planning.md` |
| PM-1803 | BACKLOG & SPRINT MANAGEMENT | Project Management & Delivery | APPROVED | 1.0.0 | July 2026 | `docs/18-project-management/1803-backlog-sprint-management.md` |
| PM-1804 | RISK & CHANGE MANAGEMENT | Project Management & Delivery | APPROVED | 1.0.0 | July 2026 | `docs/18-project-management/1804-risk-change-management.md` |
| PM-1805 | PROJECT GOVERNANCE & DELIVERY METRICS | Project Management & Delivery | APPROVED | 1.0.0 | July 2026 | `docs/18-project-management/1805-project-governance-delivery-metrics.md` |
| QA-1301 | TESTING OVERVIEW | Testing & Quality Assurance | APPROVED | 1.0.0 | July 2026 | `docs/13-testing/1301-testing-overview.md` |
| QA-1302 | UNIT TESTING SPECIFICATION | Testing & Quality Assurance | APPROVED | 1.0.0 | July 2026 | `docs/13-testing/1302-unit-testing-specification.md` |
| QA-1303 | INTEGRATION TESTING SPECIFICATION | Testing & Quality Assurance | APPROVED | 1.2.0 | July 2026 | `docs/13-testing/1303-integration-testing-specification.md` |
| QA-1304 | API TESTING SPECIFICATION | Testing & Quality Assurance | APPROVED | 1.2.0 | July 2026 | `docs/13-testing/1304-api-testing-specification.md` |
| QA-1305 | END-TO-END (E2E) TESTING SPECIFICATION | Testing & Quality Assurance | APPROVED | 1.1.0 | July 2026 | `docs/13-testing/1305-e2e-testing-specification.md` |
| QA-1306 | PERFORMANCE & LOAD TESTING SPECIFICATION | Testing & Quality Assurance | APPROVED | 1.0.0 | July 2026 | `docs/13-testing/1306-performance-load-testing-specification.md` |
| QA-1307 | SECURITY TESTING SPECIFICATION | Testing & Quality Assurance | APPROVED | 1.1.0 | July 2026 | `docs/13-testing/1307-security-testing-specification.md` |
| QA-1308 | TEST AUTOMATION & QUALITY GATES | Testing & Quality Assurance | APPROVED | 1.0.0 | July 2026 | `docs/13-testing/1308-test-automation-quality-gates.md` |
| RTM-001 | REQUIREMENTS TRACEABILITY MATRIX | — | APPROVED | 1.0.0 | July 2026 | `docs/TRACEABILITY_MATRIX.md` |
| SDK-2401 | PLATFORM SDK OVERVIEW | Platform SDK | APPROVED | 1.0.0 | July 2026 | `docs/24-platform-sdk/2401-platform-sdk-overview.md` |
| SDK-2402 | FLUTTER SDK ARCHITECTURE | Platform SDK | APPROVED | 1.0.0 | July 2026 | `docs/24-platform-sdk/2402-flutter-sdk-architecture.md` |
| SDK-2403 | TYPESCRIPT SDK ARCHITECTURE | Platform SDK | APPROVED | 1.0.0 | July 2026 | `docs/24-platform-sdk/2403-typescript-sdk-architecture.md` |
| SDK-2404 | REST API CLIENT SDK | Platform SDK | APPROVED | 1.0.0 | July 2026 | `docs/24-platform-sdk/2404-rest-api-client-sdk.md` |
| SDK-2405 | PLUGIN DEVELOPMENT KIT (PDK) | Platform SDK | APPROVED | 1.0.0 | July 2026 | `docs/24-platform-sdk/2405-plugin-development-kit.md` |
| SDK-2406 | EXTENSION POINTS & CUSTOMIZATION | Platform SDK | APPROVED | 1.0.0 | July 2026 | `docs/24-platform-sdk/2406-extension-points-customization.md` |
| SEC-1101 | SECURITY OVERVIEW | Security Specification | APPROVED | 1.0.0 | July 2026 | `docs/11-security/1101-security-overview.md` |
| SEC-1102 | IDENTITY & ACCESS MANAGEMENT | Security Specification | APPROVED | 1.0.0 | July 2026 | `docs/11-security/1102-identity-access-management.md` |
| SEC-1103 | AUTHENTICATION & SESSION SECURITY | Security Specification | APPROVED | 1.0.0 | July 2026 | `docs/11-security/1103-authentication-session-security.md` |
| SEC-1104 | API SECURITY | Security Specification | APPROVED | 1.1.0 | July 2026 | `docs/11-security/1104-api-security.md` |
| SEC-1105 | DATABASE SECURITY | Security Specification | APPROVED | 1.0.0 | July 2026 | `docs/11-security/1105-database-security.md` |
| SEC-1106 | INFRASTRUCTURE SECURITY | Security Specification | APPROVED | 1.0.0 | July 2026 | `docs/11-security/1106-infrastructure-security.md` |
| SEC-1107 | SECURE DEVELOPMENT LIFECYCLE (SSDLC) | Security Specification | APPROVED | 1.0.0 | July 2026 | `docs/11-security/1107-secure-development-lifecycle.md` |
| SEC-1108 | INCIDENT RESPONSE & DISASTER RECOVERY | Security Specification | APPROVED | 1.0.0 | July 2026 | `docs/11-security/1108-incident-response-disaster-recovery.md` |
| UI-801 | FRONTEND OVERVIEW | Frontend Specification | APPROVED | 1.0.0 | July 2026 | `docs/08-frontend/801-frontend-overview.md` |
| UI-802 | DESIGN SYSTEM | Frontend Specification | APPROVED | 1.1.0 | July 2026 | `docs/08-frontend/802-design-system.md` |
| UI-803 | COMPONENT LIBRARY | Frontend Specification | APPROVED | 1.1.0 | July 2026 | `docs/08-frontend/803-component-library.md` |
| UI-804 | CUSTOMER MOBILE APP UX | Frontend Specification | APPROVED | 1.0.0 | July 2026 | `docs/08-frontend/804-customer-mobile-app-ux.md` |
| UI-805 | BACK OFFICE UX | Frontend Specification | APPROVED | 1.1.0 | July 2026 | `docs/08-frontend/805-back-office-ux.md` |
| UI-806 | POS UX | Frontend Specification | APPROVED | 1.0.0 | July 2026 | `docs/08-frontend/806-pos-ux.md` |
| UI-807 | KITCHEN DISPLAY SYSTEM UX | Frontend Specification | APPROVED | 1.0.0 | July 2026 | `docs/08-frontend/807-kitchen-display-system-ux.md` |
| UI-808 | COURIER MOBILE APP UX | Frontend Specification | APPROVED | 1.0.0 | July 2026 | `docs/08-frontend/808-courier-mobile-app-ux.md` |
| UI-809 | OWNER DASHBOARD UX | Frontend Specification | APPROVED | 1.0.0 | July 2026 | `docs/08-frontend/809-owner-dashboard-ux.md` |
| UI-810 | DESIGN HANDOFF SPECIFICATION | Frontend Specification | APPROVED | 1.1.0 | July 2026 | `docs/08-frontend/810-design-handoff-specification.md` |

---

# Related Documents

PB-109 Terminology Glossary

ADR-1600 Architecture Decision Records Index

GOV-2701 Enterprise Architecture Governance Overview

GOV-2703 Architecture Decision Records (ADR) Governance

RTM-001 Requirements Traceability Matrix

END OF DOCUMENT
