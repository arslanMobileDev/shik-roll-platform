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

Изменения после версии 1.0.0 пока не зафиксированы.

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
