---
Document Type: Navigation
Status: ACTIVE
Last Updated: July 2026
Classification: Internal
---

# SHIK Platform Documentation

Центральная точка входа в документацию SHIK Platform.

Источником истины для содержания является документ с соответствующим Document ID. Этот README предоставляет навигацию и не заменяет PROJECT BIBLE, архитектурные документы или ADR.

---

# Foundation

- [PB-001 Project Manifest](../PROJECT_MANIFEST.md)
- [PB-002 Project Bible](../PROJECT_BIBLE.md)
- [RTM-001 Requirements Traceability Matrix](TRACEABILITY_MATRIX.md)
- [PB-109 Terminology Glossary](01-business/TERMINOLOGY_GLOSSARY.md)
- [GOV-2707 Document Registry](27-enterprise-architecture-governance/2707-document-registry.md)
- [Handbook Entry Point](00-handbook/README.md)
- [Documentation Summary](SUMMARY.md)
- [Decision Summary](../DECISIONS.md)
- [Contribution Guide](../CONTRIBUTING.md)
- [Changelog](../CHANGELOG.md)

---

# Documentation Books

| Book | Canonical Entry Point |
|---|---|
| Business | [PB-101 Business Vision](01-business/BUSINESS_VISION.md) |
| Product | [Product Overview](03-product/PRODUCT_OVERVIEW.md) |
| Architecture | [ARC-501 System Overview](05-architecture/501-system-overview.md) |
| Database | [DB-601 Database Overview](06-database/601-database-overview.md) |
| API Specification | [API-701 API Overview](07-api/701-api-overview.md) |
| Platform Overview | [PB-401 Platform Overview](07-architecture/SYSTEM_OVERVIEW.md) |
| Frontend Specification | [UI-801 Frontend Overview](08-frontend/801-frontend-overview.md) |
| Backend Specification | [BE-901 Backend Overview](09-backend/901-backend-overview.md) |
| Integrations | [Integration Overview](10-integrations/1001-integration-overview.md) |
| Security | [SEC-1101 Security Overview](11-security/1101-security-overview.md) |
| DevOps | [DEV-1201 DevOps Overview](12-devops/1201-devops-overview.md) |
| Testing | [QA-1301 Testing Overview](13-testing/1301-testing-overview.md) |
| AI & Automation | [AI-1401 AI & Automation Overview](14-ai/1401-ai-automation-overview.md) |
| Operations | [OPS-1501 Operations Overview](15-operations/1501-operations-overview.md) |
| Architecture Decision Records | [ADR-1600 ADR Index](16-adr/1600-adr-index.md) |
| Engineering | [ENG-1701 Engineering Handbook Overview](17-engineering/1701-engineering-handbook-overview.md) |
| Project Management | [PM-1801 Project Management Overview](18-project-management/1801-project-management-overview.md) |
| Compliance | [CMP-1901 Compliance Overview](19-compliance/1901-compliance-overview.md) |
| Business Continuity | [BCP-2001 Business Continuity Overview](20-business-continuity/2001-business-continuity-overview.md) |
| Performance | [PERF-2101 Performance Engineering Overview](21-performance/2101-performance-engineering-overview.md) |
| Observability | [OBS-2201 Observability Overview](22-observability/2201-observability-overview.md) |
| Enterprise Data Platform | [DATA-2301 Enterprise Data Platform Overview](23-enterprise-data-platform/2301-enterprise-data-platform-overview.md) |
| Platform SDK | [SDK-2401 Platform SDK Overview](24-platform-sdk/2401-platform-sdk-overview.md) |
| Marketplace | [Marketplace Overview](25-marketplace/2501-marketplace-overview.md) |
| Enterprise Operations | [Enterprise Operations Overview](26-enterprise-operations/2601-enterprise-operations-overview.md) |
| Architecture Governance | [GOV-2701 Architecture Governance Overview](27-enterprise-architecture-governance/2701-enterprise-architecture-governance-overview.md) |

---

# Canonical Architecture Entry Points

- [ARC-501 System Overview](05-architecture/501-system-overview.md) — канонический технический обзор.
- [PB-401 Platform Overview](07-architecture/SYSTEM_OVERVIEW.md) — высокоуровневый обзор платформы.
- [ADR-1600 Architecture Decision Records Index](16-adr/1600-adr-index.md) — реестр решений.
- [ARC-508 Technology Stack](05-architecture/508-technology-stack.md) — согласованный стек.
- [ADR-1611 Cloud Run for MVP and Kubernetes Evolution](16-adr/1611-adr-cloud-run-mvp-kubernetes-evolution.md).
- [ADR-1612 Object Storage Provider Model](16-adr/1612-adr-object-storage-provider-model.md).

---

# Compatibility and Legacy Paths

Следующие каталоги сохранены для совместимости и не являются самостоятельными каноническими книгами:

- [architecture](architecture/README.md)
- [engineering](engineering/README.md)
- [operations](operations/README.md)
- [product](product/README.md)
- [legacy decisions](19-decisions/README.md)

Новые документы следует создавать только в соответствующей нумерованной книге.

---

# Navigation Document Policy

Центральный навигационный слой обязателен и состоит из `docs/README.md`, `docs/SUMMARY.md` и GOV-2707 Document Registry. README внутри отдельных книг является опциональным, если книга уже представлена в центральной навигации.

README, SUMMARY, legacy redirect и reserved placeholder файлы являются навигационными или служебными артефактами.

Они:

- не получают Document ID;
- не считаются Architecture Decision Records;
- не могут заменять governed documents;
- должны явно указывать canonical Document ID или canonical book;
- не должны содержать новые архитектурные решения.

---

# Document Governance

Перед добавлением или изменением документа необходимо проверить:

- уникальность Document ID;
- Front Matter;
- Related Documents;
- ADR-1600 для архитектурных решений;
- GOV-2707 для общего реестра управляемых документов;
- RTM-001 для требований;
- отсутствие конфликта с каноническими entry points;
- соответствие статусам и датам из PB-109 Terminology Glossary.

---

# Documentation Validation

Read-only проверка терминологии, Document ID, Related Documents и локальных Markdown-ссылок:

```bash
python3 scripts/check-doc-terminology.py
```

Проверка не изменяет файлы и используется в GitHub Actions для pull requests, затрагивающих документацию.

END OF DOCUMENT