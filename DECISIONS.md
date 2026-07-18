---
Document Type: Decision Summary
Status: ACTIVE
Last Updated: July 2026
Classification: Internal
---

# SHIK Platform Decision Summary

## Purpose

Этот файл предоставляет краткий обзор ключевых принятых решений SHIK Platform.

Он не является Architecture Decision Record и не заменяет:

- содержание отдельных ADR;
- [ADR-1600 Architecture Decision Records Index](docs/16-adr/1600-adr-index.md);
- [GOV-2707 Document Registry](docs/27-enterprise-architecture-governance/2707-document-registry.md).

Для обоснования, последствий и условий пересмотра источником истины является указанный ADR.

---

# Accepted Decision Summary

| Область | Принятое решение | Статус источника | Источник |
|---|---|---|---|
| Repository Architecture | Monorepo | ACCEPTED | [ADR-1602](docs/16-adr/1602-adr-monorepo-architecture.md) |
| Application Architecture | Clean Architecture; modular monolith ready | ACCEPTED | [ADR-1608](docs/16-adr/1608-adr-clean-architecture-modular-monolith.md) |
| Platform Applications | Flutter; Flutter Web для Back Office и Owner Dashboard | ACCEPTED | [ADR-1606](docs/16-adr/1606-adr-flutter-cross-platform-framework.md) |
| Backend | NestJS и TypeScript | ACCEPTED | [ADR-1605](docs/16-adr/1605-adr-nestjs-backend-framework.md) |
| Primary Database | PostgreSQL | ACCEPTED | [ADR-1604](docs/16-adr/1604-adr-postgresql-primary-database.md) |
| Data Access | Prisma ORM | ACCEPTED | [ADR-1607](docs/16-adr/1607-adr-prisma-orm-data-access-layer.md) |
| API Development | API-First и Contract-First | ACCEPTED | [ADR-1609](docs/16-adr/1609-adr-api-first-contract-first-development.md) |
| Event Bus | RabbitMQ для межмодульных, межсервисных и интеграционных событий | ACCEPTED | [ADR-1603](docs/16-adr/1603-adr-event-driven-architecture.md) |
| Background Jobs | BullMQ + Redis для локальных фоновых, повторных и плановых задач | ACCEPTED SCOPE | [ADR-1603](docs/16-adr/1603-adr-event-driven-architecture.md), [ARC-512](docs/05-architecture/512-background-jobs.md) |
| Current Deployment | Google Cloud Run для MVP и early production | ACCEPTED | [ADR-1611](docs/16-adr/1611-adr-cloud-run-mvp-kubernetes-evolution.md) |
| Future Orchestration | Kubernetes только после выполнения критериев миграции | CONDITIONAL OPTION | [ADR-1611](docs/16-adr/1611-adr-cloud-run-mvp-kubernetes-evolution.md) |
| Object Storage Contract | Provider-neutral Object Storage Port | ACCEPTED | [ADR-1612](docs/16-adr/1612-adr-object-storage-provider-model.md) |
| Production Object Storage | Google Cloud Storage через GCS Adapter | ACCEPTED SCOPE | [ADR-1612](docs/16-adr/1612-adr-object-storage-provider-model.md) |
| Local Object Storage | MinIO через S3-Compatible Adapter | ACCEPTED SCOPE | [ADR-1612](docs/16-adr/1612-adr-object-storage-provider-model.md) |
| Communication Automation | Единый provider-neutral Communication Automation Center | ACCEPTED | [ADR-006](docs/03-product/COMMUNICATION_AUTOMATION_CENTER.md) |
| AI Architecture | AI-First platform principles | ACCEPTED | [ADR-1610](docs/16-adr/1610-adr-ai-first-platform-architecture.md) |

---

# Document Hierarchy Decisions

| Вопрос | Принятая граница | Источник |
|---|---|---|
| Technical System Overview | ARC-501 является каноническим техническим обзором | [ARC-501](docs/05-architecture/501-system-overview.md) |
| Platform Overview | PB-401 предоставляет высокоуровневый обзор возможностей платформы | [PB-401](docs/07-architecture/SYSTEM_OVERVIEW.md) |
| ADR Registry | ADR-1600 является каноническим реестром Architecture Decision Records | [ADR-1600](docs/16-adr/1600-adr-index.md) |
| General Document Registry | GOV-2707 является общим реестром управляемых документов | [GOV-2707](docs/27-enterprise-architecture-governance/2707-document-registry.md) |
| Communication Product Scope | PB-306 определяет требования, MVP и критерии приёмки | [PB-306](docs/03-product/306-communication-automation-center.md) |
| Component Library | UI-803 определяет библиотеку Flutter-компонентов | [UI-803](docs/08-frontend/803-component-library.md) |

---

# Maintenance Rules

Этот файл обновляется только после изменения или принятия решения в соответствующем источнике.

При расхождении:

1. отдельный ADR определяет содержание архитектурного решения;
2. ADR-1600 определяет состав и статус ADR;
3. governed document определяет содержание своей предметной области;
4. этот файл корректируется как производное краткое представление.

Новые архитектурные решения непосредственно в DECISIONS.md не принимаются.

---

# Related Documents

ADR-006 Unified Communication Automation Center

ADR-1600 Architecture Decision Records Index

ADR-1603 Event-Driven Architecture

ADR-1604 PostgreSQL as Primary Database

ADR-1605 NestJS as Backend Framework

ADR-1606 Flutter as Cross-Platform Framework

ADR-1611 Cloud Run for MVP and Kubernetes Evolution

ADR-1612 Object Storage Provider Model

GOV-2707 Document Registry

END OF DOCUMENT
