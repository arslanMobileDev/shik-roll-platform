---
Document ID: ADR-1600

Document Name: ARCHITECTURE DECISION RECORDS INDEX

Book: Enterprise Architecture Decision Records

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# ARCHITECTURE DECISION RECORDS INDEX

## Purpose

Предоставляет канонический реестр и навигационную точку для Architecture Decision Records SHIK Platform.

ADR-1600 является служебным индексным документом и не фиксирует отдельное архитектурное решение.

---

# Scope

Индекс содержит:

- идентификатор ADR;
- название;
- текущий статус;
- путь к документу;
- отметки об исключениях структуры.

Индекс не заменяет содержание отдельных ADR и не меняет их статус.

---

# Document Boundary

ADR-1600 отвечает за:

- реестр существующих ADR;
- навигацию;
- отображение текущего статуса;
- выявление пропущенных или дублирующихся идентификаторов.

ADR-1601 отвечает за:

- назначение ADR;
- принципы;
- жизненный цикл;
- структуру;
- общие правила документирования.

GOV-2703 отвечает за governance-процесс создания, рассмотрения, принятия, замены и устаревания ADR.

---

# Status Model

## Registry Document Status

APPROVED означает, что индекс утвержден как действующий навигационный документ.

## Decision Status

- PROPOSED — решение предложено и ожидает рассмотрения;
- ACCEPTED — решение принято и действует;
- SUPERSEDED — решение заменено более новым ADR;
- DEPRECATED — решение больше не рекомендуется;
- REJECTED — решение рассмотрено и отклонено.

Исторические документы могут использовать статус APPROVED. Индекс отражает фактический статус из Front Matter и не изменяет его автоматически.

---

# ADR Registry

| Document ID | Document Name | Status | Path |
|---|---|---|---|
| ADR-006 | Unified Communication Automation Center | ACCEPTED | docs/03-product/COMMUNICATION_AUTOMATION_CENTER.md |
| ADR-1601 | Architecture Decision Records Overview | APPROVED | docs/16-adr/1601-adr-overview.md |
| ADR-1602 | Monorepo Architecture | ACCEPTED | docs/16-adr/1602-adr-monorepo-architecture.md |
| ADR-1603 | Event-Driven Architecture | ACCEPTED | docs/16-adr/1603-adr-event-driven-architecture.md |
| ADR-1604 | PostgreSQL as Primary Database | ACCEPTED | docs/16-adr/1604-adr-postgresql-primary-database.md |
| ADR-1605 | NestJS as Backend Framework | ACCEPTED | docs/16-adr/1605-adr-nestjs-backend-framework.md |
| ADR-1606 | Flutter as Cross-Platform Framework | ACCEPTED | docs/16-adr/1606-adr-flutter-cross-platform-framework.md |
| ADR-1607 | Prisma ORM as Data Access Layer | ACCEPTED | docs/16-adr/1607-adr-prisma-orm-data-access-layer.md |
| ADR-1608 | Clean Architecture and Modular Monolith Ready | ACCEPTED | docs/16-adr/1608-adr-clean-architecture-modular-monolith.md |
| ADR-1609 | API-First and Contract-First Development | ACCEPTED | docs/16-adr/1609-adr-api-first-contract-first-development.md |
| ADR-1610 | AI-First Platform Architecture | ACCEPTED | docs/16-adr/1610-adr-ai-first-platform-architecture.md |
| ADR-1611 | Cloud Run for MVP and Kubernetes Evolution | SUPERSEDED | docs/16-adr/1611-adr-cloud-run-mvp-kubernetes-evolution.md |
| ADR-1612 | Object Storage Provider Model | ACCEPTED | docs/16-adr/1612-adr-object-storage-provider-model.md |
| ADR-1613 | Beget Cloud for MVP and Infrastructure Evolution | ACCEPTED | docs/16-adr/1613-adr-beget-cloud-mvp-deployment.md |

---

# Structural Exceptions

## ADR-006

ADR-006 находится в каталоге docs/03-product, а не в стандартном каталоге docs/16-adr.

Идентификатор и путь сохраняются для совместимости с существующими ссылками.

Перемещение или переименование ADR-006 требует отдельного решения и не выполняется через обновление индекса.

---

# Maintenance Rules

Индекс должен обновляться, когда:

- создается новый ADR;
- изменяется статус ADR;
- ADR заменяется другим решением;
- изменяется путь к ADR;
- обнаруживается исторический ADR вне стандартного каталога.

При обновлении необходимо проверить:

- уникальность Document ID;
- соответствие статуса Front Matter;
- существование пути;
- отсутствие пропусков в ожидаемой последовательности;
- корректность Related Documents;
- наличие ссылки на заменяющий ADR для статуса SUPERSEDED.

---

# Source of Truth

Для содержания решения источником истины является соответствующий ADR.

Для текущего статуса источником истины является Front Matter соответствующего ADR.

ADR-1600 предоставляет сводное представление и должен быть синхронизирован с этими источниками.

---

# Related Documents

ADR-1601 Architecture Decision Records Overview

GOV-2701 Enterprise Architecture Governance Overview

GOV-2702 Architecture Review Board

GOV-2703 Architecture Decision Records (ADR) Governance

END OF DOCUMENT