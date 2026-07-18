---
Document ID: ADR-1607

Document Name: ADR — PRISMA ORM AS DATA ACCESS LAYER

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

# ADR — PRISMA ORM AS DATA ACCESS LAYER

## Status

Accepted

---

# Context

SHIK Platform использует PostgreSQL в качестве основной базы данных и NestJS как backend framework.

Необходимо выбрать единый слой доступа к данным, обеспечивающий:

- типобезопасность;
- высокую производительность;
- поддержку миграций;
- удобную разработку;
- долгосрочную сопровождаемость.

---

# Problem

Основные варианты:

- Prisma ORM
- TypeORM
- Sequelize
- Drizzle ORM
- MikroORM
- Hibernate

Требования

- TypeScript First
- Strong Type Safety
- Migration Support
- Excellent PostgreSQL Support
- Developer Productivity
- Long-Term Maintenance

---

# Decision

Использовать **Prisma ORM** как основной слой доступа к данным SHIK Platform.

---

# Rationale

Prisma обеспечивает:

- полную типобезопасность;
- автоматическую генерацию клиента;
- декларативную схему данных;
- встроенные миграции;
- отличную поддержку PostgreSQL;
- высокую производительность разработки;
- современный Developer Experience;
- зрелую документацию.

---

# Alternatives Considered

## TypeORM

Advantages

- Популярность
- Decorator Based

Disadvantages

- Более сложная поддержка
- Менее строгая типизация
- Исторические проблемы со стабильностью

---

## Sequelize

Advantages

- Зрелая экосистема

Disadvantages

- Менее современный API
- Ограниченная типобезопасность
- Более сложная поддержка TypeScript

---

## Drizzle ORM

Advantages

- Отличная производительность
- SQL First
- Хорошая типизация

Disadvantages

- Более молодая экосистема
- Меньше готовых решений
- Меньше корпоративного опыта эксплуатации

---

## MikroORM

Advantages

- Хорошая архитектура
- Unit of Work

Disadvantages

- Более высокая сложность
- Меньшая экосистема

---

## Hibernate

Advantages

- Enterprise Ready
- Богатая функциональность

Disadvantages

- Java Stack
- Не соответствует выбранной технологической платформе

---

# Consequences

Positive

- End-to-End Type Safety
- Auto Generated Client
- Excellent DX
- Reliable Migrations
- Schema Synchronization
- Strong PostgreSQL Support

Negative

- Зависимость от Prisma CLI
- Ограничения при использовании некоторых PostgreSQL Extensions
- Иногда требуется использование Raw SQL

---

# Risks

- Vendor Lock-In
- Изменения Prisma API
- Сложные SQL-запросы

Mitigation

- Repository Pattern
- Raw SQL только при необходимости
- Регулярные обновления Prisma
- ADR Documentation

---

# Architecture Principles

- Repository Pattern
- One Prisma Client Per Service
- Explicit Transactions
- UUID Primary Keys
- Soft Delete Support
- Optimistic Locking Where Required

---

# Migration Strategy

- Version Controlled
- Automatic Generation
- Manual Review Before Production
- Rollback Plan Required

---

# Query Guidelines

Preferred

- Prisma Client
- Typed Queries
- Transactions
- Batch Operations

Allowed

- Raw SQL For Complex Analytics
- Database Functions
- Stored Procedures When Justified

---

# Performance Strategy

- Connection Pooling
- Query Optimization
- Proper Indexing
- Pagination
- Select Only Required Fields
- Avoid N+1 Queries

---

# Success Criteria

- Fully Type-Safe Data Access
- Reliable Database Migrations
- High Developer Productivity
- Consistent Data Layer
- Easy Maintenance

---

# Review Criteria

Пересмотр решения возможен при:

- прекращении поддержки Prisma;
- появлении существенных ограничений производительности;
- переходе на другую СУБД или архитектурную модель.

---

# Related Documents

DB-601 Database Overview

BE-901 Backend Overview

BE-902 Backend Coding Standards

ADR-1604 PostgreSQL as Primary Database

END OF DOCUMENT