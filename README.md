# SHIK Platform

> **Cloud-native Restaurant Automation Platform**
>
> **First implementation:** SHIK ROLL

---

# Overview

SHIK Platform is a modern cloud-native ecosystem designed to automate every aspect of a restaurant business.

The platform is being developed as an independent solution that is not tied to any existing restaurant automation provider.

SHIK ROLL is the first brand built on top of the platform.

The long-term vision is to create a scalable restaurant operating system capable of serving:

- Single restaurants
- Multi-branch businesses
- Franchise networks
- Multiple restaurant brands

---

# Vision

Build one unified platform where every part of the restaurant works together:

Customer

↓

Mobile App

↓

Backend

↓

Kitchen

↓

Delivery

↓

POS

↓

Inventory

↓

Analytics

↓

Owner Dashboard

↓

Back Office

---

# Core Principles

The platform follows several engineering principles.

- Documentation First
- Clean Architecture
- API-First
- Modular Design
- Cloud-Native
- Security by Design
- Vendor Independence
- Configuration First
- AI Assisted Development

Complete principles are described in:

```
PROJECT_MANIFEST.md
```

---

# Platform Architecture

The platform consists of three logical layers.

## Core Platform

Contains reusable business services.

Examples:

- Authentication
- Users
- Menu
- Orders
- Kitchen
- Delivery
- POS
- Inventory
- Loyalty
- Notifications
- Analytics
- Payments

---

## Brand Layer

Contains everything related to a restaurant brand.

Example:

SHIK ROLL

- Logo
- Colors
- Marketing
- Photos
- Categories
- Promotions

---

## Configuration Layer

Contains settings editable through Back Office.

Examples:

- Menu
- Prices
- Photos
- Delivery Zones
- Branches
- Employees
- Promotions
- Working Hours
- Stop Lists

Changing configuration never requires application recompilation.

---

# Applications

The ecosystem consists of several independent applications.

## Customer App

Flutter application for customers.

Features:

- Registration
- Ordering
- Payments
- Loyalty
- Delivery Tracking
- Pickup
- Preorder

---

## Kitchen App

Kitchen Display System (KDS)

Features:

- Live Orders
- Timers
- Cooking Status
- Stop List
- Recipes
- Performance Analytics

---

## Courier App

Courier application.

Features:

- Route
- Navigation
- Order Status
- Earnings
- Push Notifications

---

## POS

Restaurant cashier application.

Features:

- Sales
- Payments
- Fiscal Receipts
- Shift Management
- Returns

---

## Back Office

Web administration panel.

Features:

- Menu
- Categories
- Promotions
- Inventory
- Employees
- Branches
- Reports

---

## Owner Dashboard

Business management dashboard.

Features:

- Revenue
- KPIs
- Analytics
- Profitability
- Employee Performance
- Reports

---

# Technology Stack

## Mobile

Flutter

---

## Backend

NestJS

---

## Database

PostgreSQL

Prisma ORM

---

## Cache

Redis

---

## Background Jobs

BullMQ

---

## Event Bus

RabbitMQ

---

## Frontend

Flutter

Flutter Web

---

## Infrastructure

Beget Cloud VPS

Docker Compose

Nginx

Beget PostgreSQL DBaaS

Beget S3

GitHub Container Registry (GHCR)

GitHub Actions

Prometheus

Grafana

Loki

---

## Authentication

Firebase Authentication (candidate; production use requires CMP-1908 compliance gate and a separate architecture decision)

---

## Push Notifications

Firebase Cloud Messaging

---

## Maps

The platform supports multiple map providers through a dedicated abstraction layer.

Supported providers:

- Google Maps
- Yandex Maps
- 2GIS

Additional providers can be added without changing business logic.

---

## Payments

Platform supports modular payment integrations.

Examples:

- Bank Cards
- SBP (Fast Payment System)
- Future payment providers

---

# Artificial Intelligence

The project actively uses AI during development.

## Solution Architect

ChatGPT

Responsibilities:

- Product Architecture
- Engineering Handbook
- Documentation
- Technical Decisions

---

## AI Software Engineer

Claude Code

Responsibilities:

- Backend
- Flutter
- API
- Infrastructure
- Refactoring

---

## AI Designer

Claude Design

Responsibilities:

- UI
- UX
- Design System
- Prototypes

---

# Repository Structure

```
SHIK-ROLL-PLATFORM/

README.md

PROJECT_MANIFEST.md

PROJECT_BIBLE.md

DECISIONS.md

CHANGELOG.md

CONTRIBUTING.md

docs/

assets/

design/

prompts/

apps/

packages/

scripts/

docker/

infrastructure/
```

---

# Engineering Handbook

Project documentation is organized as an Engineering Handbook.

Books include:

- Foundation
- Business
- Product
- Brand & Design
- Architecture
- Engineering
- Operations
- Future Modules

---

# Development Workflow

Business Analysis

↓

Documentation

↓

Architecture

↓

UI / UX

↓

Development

↓

Testing

↓

Deployment

↓

Support

---

# Git Workflow

Feature Branch

↓

Development

↓

Pull Request

↓

Review

↓

Merge

↓

Release

---

# Documentation Rule

Documentation is the single source of truth.

If documentation and implementation conflict:

**Documentation wins.**

---

# Project Status

Current Stage:

Engineering Handbook

Foundation

---

# Roadmap

Phase 1

Engineering Handbook

↓

Phase 2

Design System

↓

Phase 3

Backend

↓

Phase 4

Flutter Applications

↓

Phase 5

Infrastructure

↓

Phase 6

Testing

↓

Phase 7

Production Release

---

# License

Internal Development

Copyright © Arslan Berslanov

---

# Contacts

Project Owner

Arslan Berslanov

Repository

SHIK-ROLL-PLATFORM

---

# SHIK Platform

Building the next generation restaurant operating system.