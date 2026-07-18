---
Document ID: ADR-1604

Document Name: ADR — POSTGRESQL AS PRIMARY DATABASE

Book: Enterprise Architecture Decision Records

Version: 1.0.0

Status: ACCEPTED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Decision Date: July 2026
Last Updated: July 2026


Classification: Internal
---

# ADR — POSTGRESQL AS PRIMARY DATABASE

## Status

Accepted

---

# Context

SHIK Platform обрабатывает критически важные бизнес-данные:

- Customers
- Employees
- Orders
- Payments
- Inventory
- Loyalty
- Analytics
- Audit Logs

Система требует надежной транзакционной базы данных с поддержкой ACID, масштабируемости и богатых возможностей SQL.

---

# Problem

Необходимо выбрать основную систему управления базами данных.

Основные варианты:

- PostgreSQL
- MySQL
- MariaDB
- MongoDB
- CockroachDB

Требования:

- ACID-транзакции;
- высокая надежность;
- расширяемость;
- поддержка JSON;
- полнотекстовый поиск;
- зрелая экосистема;
- совместимость с Prisma ORM.

---

# Decision

Использовать **PostgreSQL** как основную реляционную базу данных SHIK Platform.

---

# Rationale

PostgreSQL обеспечивает:

- полную поддержку ACID;
- богатый SQL-функционал;
- JSON/JSONB;
- Full Text Search;
- оконные функции;
- Common Table Expressions (CTE);
- Row-Level Security;
- расширяемость через Extensions;
- зрелую экосистему;
- отличную совместимость с Prisma ORM.

---

# Alternatives Considered

## MySQL

Advantages

- Простота
- Высокая популярность

Disadvantages

- Менее богатый SQL
- Ограниченные аналитические возможности
- Более слабая поддержка сложных запросов

---

## MariaDB

Advantages

- Совместимость с MySQL
- Open Source

Disadvantages

- Меньшая экосистема
- Более слабая интеграция с современными инструментами

---

## MongoDB

Advantages

- Гибкая схема
- Простота хранения документов

Disadvantages

- Не подходит для финансовых транзакций
- Ограниченные ACID-возможности
- Более сложная поддержка связей между сущностями

---

## CockroachDB

Advantages

- Горизонтальное масштабирование
- Multi-Region

Disadvantages

- Избыточная сложность
- Более высокая стоимость эксплуатации
- Не требуется на текущем этапе проекта

---

# Consequences

Positive

- ACID Transactions
- Strong Consistency
- Excellent SQL Support
- JSONB Support
- Mature Tooling
- Reliable Replication
- Rich Ecosystem

Negative

- Вертикальное масштабирование имеет ограничения
- Требуется квалифицированное администрирование
- Некоторые сложные запросы требуют оптимизации

---

# Risks

- Рост объема данных
- Медленные запросы
- Блокировки
- Репликационные задержки

Mitigation

- Index Optimization
- Query Optimization
- Read Replicas
- Connection Pooling
- Partitioning
- Monitoring
- Regular Maintenance

---

# Database Principles

- Normalize Transactional Data
- Use Foreign Keys
- Soft Delete Where Required
- UUID Primary Keys
- UTC Timestamps
- Optimistic Locking Where Appropriate

---

# Extensions

Approved

- pgcrypto
- uuid-ossp
- pg_trgm

Future

- PostGIS
- TimescaleDB

---

# Scalability Strategy

Current

- Single Primary Database

Near Future

- Read Replicas

Future

- Partitioning
- Horizontal Scaling
- Multi-Region Ready

---

# Backup Strategy

- Hourly Incremental
- Daily Full Backup
- Point-in-Time Recovery
- Regular Restore Testing

---

# Success Criteria

- Stable Transaction Processing
- Reliable Data Integrity
- High Query Performance
- Easy Schema Evolution
- Operational Simplicity

---

# Review Criteria

Пересмотр решения возможен при:

- переходе к глобальной мульти-региональной архитектуре;
- существенном изменении требований к масштабируемости;
- появлении новых бизнес-требований, не покрываемых PostgreSQL.

---

# Related Documents

DB-601 Database Overview

SEC-1105 Database Security

DEV-1205 Docker & Containerization

ARC-505 DOMAIN MODEL

END OF DOCUMENT