---
Document ID: PB-109

Document Name: TERMINOLOGY GLOSSARY

Book: Business

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Last Updated: July 2026

Classification: Internal
---

# TERMINOLOGY GLOSSARY

## Purpose

Определяет канонические названия архитектурных, продуктовых и технологических сущностей SHIK Platform.

Канонический термин должен использоваться в Front Matter, заголовках, Related Documents, диаграммах, требованиях и новых документах.

Русский язык может использоваться для пояснений, но канонические имена компонентов и технологий не переводятся и не создают отдельные сущности.

---

# Platform Documents

## ARC-501 System Overview

Канонический технический обзор архитектуры.

Допустимое краткое название после первого упоминания:

- Technical System Overview

## PB-401 Platform Overview

Высокоуровневый обзор платформы, её возможностей и приложений.

Запрещено использовать PB-401 как канонический технический обзор.

---

# Platform Applications

Канонические имена:

- Customer App
- Back Office
- Owner Dashboard
- POS
- Kitchen Display System
- Courier App

Допустимые сокращения:

- POS — после определения контекста;
- KDS — после первого полного упоминания Kitchen Display System.

Запрещённые варианты:

- Backoffice
- Back-Office
- Owner Panel
- Admin Panel — если имеется в виду Back Office.

---

# Communication Domain

## Communication Automation Center

Каноническое имя продуктового модуля управления правилами, шаблонами, каналами и журналом коммуникаций.

Запрещённый сокращённый вариант:

- Communication Center

## Communication Service

Каноническое имя backend-реализации коммуникационного домена.

Communication Automation Center и Communication Service не являются взаимозаменяемыми терминами.

---

# Messaging and Background Processing

## RabbitMQ Event Bus

Каноническая роль RabbitMQ:

- межмодульные события;
- межсервисные события;
- интеграционные события.

После первого упоминания допускается RabbitMQ.

## BullMQ Background Job Queue

Каноническая роль BullMQ + Redis:

- локальные фоновые задания;
- retries;
- scheduled jobs;
- worker processing.

RabbitMQ Event Bus и BullMQ Background Job Queue не являются взаимозаменяемыми терминами.

---

# Deployment

## Google Cloud Run

Каноническое полное имя production runtime для MVP и early production.

После первого полного упоминания в одном разделе допускается Cloud Run.

## Kubernetes

Future evolution option по критериям ADR-1611.

Kubernetes не должен называться текущим production runtime без нового принятого ADR.

---

# Object Storage

## Object Storage Port

Каноническое имя внутреннего provider-neutral контракта приложения.

## Google Cloud Storage

Production provider в Google Cloud.

После первого полного упоминания допускается GCS.

## S3-Compatible Adapter

Каноническое имя адаптера для MinIO и других S3-compatible providers.

## MinIO

Local/development provider или approved self-hosted provider.

MinIO не должен называться безусловным production provider.

## S3-compatible

Каноническое написание общего признака совместимости.

Имена собственных сущностей используют:

- S3-Compatible Adapter
- S3-compatible provider
- S3-compatible object storage

---

# Architecture Terms

Каноническое написание:

- Event-Driven Architecture
- API-First
- Contract-First
- AI-First
- Cloud-Native
- Multi-Tenant
- Real-Time
- Self-Hosted
- Provider-Neutral

---

# Document Terms

Канонические сокращения:

- ADR — Architecture Decision Record
- API — Application Programming Interface
- RTM — Requirements Traceability Matrix
- MVP — Minimum Viable Product
- SDK — Software Development Kit

Related Documents должны использовать существующий Document ID и каноническое Document Name.

---

# Status and Date Fields

## Governed Documents

Allowed statuses:

- DRAFT
- REVIEW
- APPROVED
- DEPRECATED

Required date field:

- Last Updated

## Architecture Decision Records

Allowed statuses:

- PROPOSED
- ACCEPTED
- SUPERSEDED
- DEPRECATED
- REJECTED

Required date fields for an accepted ADR:

- Decision Date
- Last Updated

Decision Date records when the decision was accepted.

Last Updated records the most recent documentation change and does not change the original decision date.

## Navigation and Service Files

Allowed statuses:

- ACTIVE
- DEPRECATED
- RESERVED

README, SUMMARY, legacy redirect and reserved placeholder files use Document Type and do not receive Document ID.

---

# Alias Rules

Допустимый алиас:

- вводится только после полного канонического имени;
- используется в пределах того же раздела или документа;
- не применяется в Front Matter;
- не применяется как подпись Related Documents;
- не создаёт новый модуль или архитектурную сущность.

Запрещённый алиас должен заменяться каноническим термином.

---

# Change Rules

Изменение канонического термина требует:

- проверки всех документов;
- обновления PB-109;
- проверки Related Documents;
- оценки влияния на API, код, схемы и тесты;
- нового ADR, если изменение затрагивает архитектурное решение.

---

# Related Documents

PB-001 PROJECT MANIFEST

PB-002 PROJECT BIBLE

PB-101 BUSINESS VISION

PB-108 BUSINESS RULES

ARC-501 SYSTEM OVERVIEW

PB-401 PLATFORM OVERVIEW

ADR-1600 ARCHITECTURE DECISION RECORDS INDEX

END OF DOCUMENT