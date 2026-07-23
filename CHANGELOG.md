---
Document Type: Changelog
Status: ACTIVE
Last Updated: July 2026
Classification: Internal
---

# Changelog

Этот файл содержит журнал значимых архитектурных, документационных и governance-изменений SHIK Platform.

Изменения группируются в разделе `Unreleased` до утверждения стабильной версии. Запись версии и даты релиза выполняется только после успешного полного аудита и отдельного подтверждения владельца проекта.

---

## Unreleased

### Added

- CMP-1908 defining Russian personal-data, separate-consent, public-offer and production-release requirements.
- ADR-1613 selecting Beget Cloud VPS, Beget PostgreSQL DBaaS and Beget S3 for MVP and early production.
- Product Book requirements for pre-launch catalog preparation through Back Office.
- UJ-013 Prepare and Publish Catalog.
- CAP-006 Product Catalog Management.

### Changed

- Product requirements, Customer App UX, Back Office UX, Customer and Order APIs, database schemas and backend services now support versioned legal documents, separate consent evidence and immutable public-offer snapshots.
- Firebase Authentication is now a candidate gated by legal, privacy and architecture review before Russian production use.
- Production launch is blocked until operator, Roskomnadzor, legal-text, external-provider and privacy-disclosure requirements are verified.
- Product, architecture, database, backend, compliance, performance, data-platform and business-continuity documents synchronized on Beget S3 for staging and production.
- The S3-Compatible Adapter is the current production adapter; MinIO remains local and GCS remains an optional future adapter.
- Recovery copies containing personal data are constrained to legally approved Russian regions unless separately reviewed.
- Deployment documentation synchronized on Beget Cloud VPS, Docker Compose, Nginx, Beget PostgreSQL DBaaS and GitHub Container Registry.
- Project foundation, terminology, platform overview, DevOps and technology lifecycle documents now reference ADR-1613 as the current infrastructure decision.
- ADR-1611 superseded by ADR-1613 after the production infrastructure provider changed from Google Cloud to Beget Cloud.
- ADR-1612 updated to use Beget S3 for staging and production while preserving the provider-neutral Object Storage Port.
- ADR-1600, DECISIONS.md, SUMMARY and GOV-2707 synchronized with the current infrastructure decision.
- PB-301, PB-303, PB-304 and PB-305 updated to version 1.1.0.
- Menu and product requirements now define Draft, Preview, Published and Hidden behavior.
- MVP catalog management now includes image replacement, safe deletion, sorting, Stop List and manual Popular, New and Featured flags.
- UI-805, API-706 and DB-607 updated to version 1.1.0.
- Back Office UX now defines import, Draft, Preview, Publish and catalog media workflows.
- Menu API now defines repeatable `source_key` imports, lifecycle, ordering, merchandising and safe media endpoints.
- Menu schema now defines import jobs, publication versions, stable source keys and Object Storage metadata.
- BE-906, ARC-504, ARC-509 and ARC-512 updated to version 1.1.0.
- Backend processing now covers repeatable catalog imports, publication lifecycle, catalog events and media operations.
- Public caching is isolated from Draft and Preview data and switches only after successful publication.
- Background jobs now define catalog import, cache warmup and safe deleted-image cleanup behavior.
- QA-1303, QA-1304, QA-1305, QA-1307 and SEC-1104 updated to version 1.1.0.
- Catalog acceptance coverage now includes import idempotency, Draft isolation, publication, media lifecycle and branch-scoped availability.
- Catalog administration security now covers privileged publication, import validation, media validation and Object Storage data protection.
- UI-802, UI-803 and UI-810 updated to version 1.1.0.
- Claude Design handoff now includes catalog screens, lifecycle states, media states and representative menu data coverage.
- The Flutter component contract now includes reusable catalog administration components and their required test states.
- PM-1801 and PM-1802 updated to version 1.1.0.
- The project lifecycle now defines explicit Product Book, Claude Design and Claude Code entry gates.
- MVP planning now includes module review checkpoints and a pre-launch catalog readiness milestone.
- API-706, DB-607, BE-906, ARC-504, QA-1303 and QA-1304 updated to version 1.2.0.
- Catalog import identity is now scoped by `menu_id + source_key`, preserving product UUID when a category changes.
- Product, media and import lifecycle values are explicit, and the legacy product `is_active` ambiguity is removed.
- RabbitMQ remains the current event bus; only its topology evolution is listed as future work.

---

## [1.0.0] - 2026-07-19

Стабильная базовая версия архитектурной и проектной документации SHIK Platform.

Эта версия фиксирует состояние документации и architecture governance. Она не является объявлением production-релиза приложения.

### Added

- ADR-1611 с моделью Cloud Run для MVP и эволюционным переходом к Kubernetes.
- ADR-1612 с provider-agnostic моделью Object Storage.
- Канонический документ PB-306 для Communication Automation Center.
- Содержательное назначение UI-803 как спецификации Flutter Component Library.
- Канонический ADR-1600 как индекс и реестр Architecture Decision Records.
- PB-109 Terminology Glossary и GOV-2707 Document Registry.
- `DECISIONS.md` как краткий обзор принятых решений без замены ADR.
- `CONTRIBUTING.md` с правилами изменения документации.
- Центральный навигационный слой через `docs/README.md` и `docs/SUMMARY.md`.
- Read-only валидатор документации и GitHub Actions workflow для автоматической проверки.

### Changed

- ARC-501 закреплён как канонический технический System Overview; PB-401 сохранён как высокоуровневый Platform Overview.
- Frontend stack согласован на Flutter и Flutter Web; TypeScript сохранён для NestJS backend и TypeScript SDK.
- RabbitMQ закреплён как event bus, а BullMQ — как внутренний планировщик фоновых задач.
- Deployment model согласован: Cloud Run для MVP, Kubernetes как целевая эволюция по критериям ADR-1611.
- Object Storage описан через provider abstraction с MinIO для локальной среды и Google Cloud Storage для production.
- ADR-006 и PB-306 согласованы как архитектурное решение и продуктовая спецификация одной области.
- Related Documents, Document ID references, терминология и навигация синхронизированы с каноническими документами.

### References

- [Decision Summary](DECISIONS.md)
- [Contribution Guide](CONTRIBUTING.md)
- [ADR-1600 Architecture Decision Records Index](docs/16-adr/1600-adr-index.md)
- [GOV-2707 Document Registry](docs/27-enterprise-architecture-governance/2707-document-registry.md)
- [Documentation Summary](docs/SUMMARY.md)

---

**END OF DOCUMENT**
