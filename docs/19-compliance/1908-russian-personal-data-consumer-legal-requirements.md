---
Document ID: CMP-1908

Document Name: RUSSIAN PERSONAL DATA & CONSUMER LEGAL REQUIREMENTS

Book: Compliance & Legal

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# RUSSIAN PERSONAL DATA & CONSUMER LEGAL REQUIREMENTS

## Purpose

Определяет обязательные системные требования SHIK Platform для обработки персональных данных в российском production-контуре, публикации публичной оферты и дистанционного оформления заказов.

Документ задаёт требования к продукту и реализации. Он не является готовой публичной офертой, политикой обработки персональных данных или юридическим заключением. Финальные тексты и применимость правовых норм подтверждаются квалифицированным российским юристом до production launch.

---

# Scope

Требования применяются к:

- Customer App;
- Back Office;
- Backend API;
- PostgreSQL;
- Object Storage;
- журналам и резервным копиям;
- заказам и платежным событиям;
- коммуникациям и маркетингу;
- внешним провайдерам;
- staging и production данным.

---

# Personal Data Operator Readiness

До начала production-обработки владелец продукта должен:

- определить юридическое лицо или ИП, являющееся оператором персональных данных;
- сформировать перечень целей, категорий данных, субъектов и операций обработки;
- определить правовые основания обработки по каждой цели;
- проверить обязанность уведомления Роскомнадзора до начала обработки;
- назначить ответственных лиц;
- утвердить внутренние политики, модель угроз, меры защиты, retention and deletion rules;
- вести реестр обработчиков и внешних провайдеров;
- обеспечить обработку обращений субъектов и инцидентов.

---

# Russian Data Localization

Для персональных данных граждан Российской Федерации production-контур должен использовать российский регион для первичного сбора и операций, охватываемых требованиями локализации.

Current Target

- Beget Cloud in a Russian region;
- Beget PostgreSQL DBaaS;
- Beget S3;
- российский контур журналов и резервных копий.

Персональные данные не передаются в другой регион или внешнему провайдеру без:

- data-flow inventory;
- определения правового основания;
- privacy impact assessment;
- security review;
- contract and processor review;
- architecture review;
- письменного решения владельца проекта.

---

# Separate Consent Model

Согласие на обработку персональных данных оформляется отдельно от:

- публичной оферты;
- регистрации;
- пользовательских условий;
- маркетингового согласия;
- других документов, подтверждаемых пользователем.

Each Consent Record Stores

- purpose;
- legal basis;
- document type and version;
- content hash;
- granted or withdrawn status;
- timestamp;
- channel and source;
- customer or verified session reference;
- IP address and user agent when permitted;
- immutable evidence identifier.

Marketing Consent

- отдельное;
- необязательное;
- выключено по умолчанию;
- не является условием регистрации или оформления заказа;
- может быть отозвано через Legal & Privacy Center;
- применяется до отправки рекламной коммуникации.

Отзыв согласия не удаляет автоматически данные, которые оператор обязан или вправе продолжать обрабатывать на другом законном основании. Такое основание и срок хранения должны быть документированы.

---

# Public Offer

До оформления заказа пользователю должна быть доступна действующая юридически проверенная публичная оферта.

The Published Offer Must Support

- seller legal identity and contact details;
- предмет договора и описание товаров;
- prices, discounts and payment terms;
- delivery and pickup terms;
- order confirmation rules;
- cancellation, refund and claim rules;
- ответственность сторон;
- effective date and version;
- stable public URL;
- locale;
- content hash.

Checkout Requirements

- показать ссылку на действующую оферту до отправки заказа;
- использовать однозначное действие оформления заказа;
- зафиксировать accepted offer version, content hash and timestamp;
- проверить опубликованную версию на backend;
- сохранить неизменяемый legal snapshot вместе с заказом;
- не изменять исторические условия после публикации новой версии.

---

# Legal Document Lifecycle

Supported Types

- Public Offer;
- Personal Data Processing Policy;
- Privacy Notice;
- Personal Data Consent;
- Marketing Consent;
- Cookie or Tracking Notice when applicable.

Lifecycle

Draft

↓

Legal Review

↓

Approved

↓

Published

↓

Superseded

Rules

- Published versions are immutable.
- A version referenced by an order, consent or audit record cannot be deleted.
- Publication requires an authorized owner or legal role.
- Every publication and access to acceptance evidence is audited.
- Only one current published version per document type, locale and legal entity is allowed.

---

# Customer Rights and Product Flows

The product must support:

- access to current legal documents without authentication;
- consent history;
- withdrawal of optional consent;
- request for access;
- request for correction;
- request for export;
- request for deletion;
- identity verification for sensitive requests;
- request status tracking;
- account deletion flow;
- retention of legally required order, fiscal and security records;
- clear explanation when immediate deletion is not legally permitted.

---

# Back Office Requirements

Back Office must provide:

- legal-document registry;
- Draft, Review, Approved, Published and Superseded states;
- preview before publication;
- effective-date scheduling;
- immutable published versions;
- role-based publication;
- acceptance-evidence search;
- data-subject request queue;
- audit trail;
- export controls and reason capture;
- prohibition on destructive deletion of referenced versions.

---

# Data Model Requirements

Required Records

- legal_documents;
- customer_consents;
- customer_legal_acceptances;
- data_subject_requests;
- order legal snapshot;
- audit events.

Personal-data consent and marketing consent must never be represented by one boolean field.

Notification channel preferences are not evidence of legal consent.

---

# External Provider Gate

Before an external provider processes identifiers, contact information, addresses, device tokens, IP addresses, order data or other personal data, the project must verify:

- data categories and purposes;
- storage and processing locations;
- cross-border transfer;
- subcontractors;
- retention and deletion;
- security measures;
- contract and data-processing terms;
- incident notification;
- ability to support data-subject requests.

---

# Firebase Authentication Gate

Firebase Authentication is a candidate, not an approved Russian production identity provider.

Before production use, the project must verify:

- exact personal-data flow;
- storage and processing locations;
- cross-border-transfer requirements;
- contractual roles and terms;
- retention and deletion;
- incident handling;
- compatibility with Russian localization requirements.

If these conditions are not legally and technically confirmed, another identity implementation must be selected through a separate ADR.

This document does not select the replacement provider.

---

# Production Release Gates

Production launch is blocked until:

- operator identity is confirmed;
- Roskomnadzor notification applicability is decided and completed when required;
- public offer is approved by legal counsel;
- personal-data policy and separate consent are approved;
- optional marketing consent is separate and disabled by default;
- Beget production location and contracts are verified;
- external-provider register and data-flow map are complete;
- Firebase Authentication has an accepted ADR or is removed from production scope;
- App Store and Google Play privacy disclosures are prepared;
- backup location, restoration and deletion procedures are tested;
- security, privacy and acceptance tests pass.

---

# Normative Reference Set

The legal review must consider the current editions applicable on the launch date, including:

- Federal Law No. 152-FZ On Personal Data;
- Federal Law No. 156-FZ of 24 June 2025 regarding separate personal-data consent;
- Law No. 2300-1 On Consumer Rights Protection;
- Civil Code of the Russian Federation, including public-offer and distance-selling provisions;
- Federal Law No. 54-FZ regarding cash-register equipment and receipts;
- applicable Russian distance-selling rules;
- applicable Roskomnadzor requirements.

---

# Related Documents

PB-305 Product Requirements

UI-804 Customer Mobile App UX

UI-805 Back Office UX

API-704 Customer API

API-707 Order API

DB-605 Customer Schema

DB-608 Order Schema

BE-904 Customer Service

BE-907 Order Service

CMP-1901 Compliance Overview

CMP-1905 Privacy Policy & Data Processing Architecture

CMP-1907 Legal Requirements & Regulatory Compliance

ADR-1613 Beget Cloud for MVP and Infrastructure Evolution

END OF DOCUMENT