---
Document ID: UI-810

Document Name: DESIGN HANDOFF SPECIFICATION

Book: Frontend Specification

Version: 1.1.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Design Authority: Claude Design

Last Updated: July 2026

Classification: Internal
---

# DESIGN HANDOFF SPECIFICATION

## Purpose

Определяет правила передачи дизайна из Design System в разработку.

---

# Objectives

- Единый источник истины
- Минимизация неоднозначности
- Готовность к разработке
- Полная трассируемость

---

# Design Deliverables

Required

- User Flows
- Wireframes
- High Fidelity Mockups
- Interactive Prototype
- Design Tokens
- Component Library
- Icons
- Assets

---

# Screen Specification

Каждый экран обязан содержать

- Screen ID
- Screen Name
- Purpose
- Navigation
- Components
- States
- Permissions
- API Integration
- Validation Rules
- Accessibility Requirements

---

# Component Specification

Каждый компонент обязан содержать

- Component ID
- Name
- Description
- Variants
- States
- Properties
- Events
- Design Tokens
- Accessibility

---

# Responsive Rules

Required

- Mobile
- Tablet
- Desktop

---

# Accessibility

Required

- WCAG AA
- Keyboard Navigation
- Screen Reader Support
- Focus Indicators
- Minimum Touch Area

---

# Design Tokens

Required

- Colors
- Typography
- Spacing
- Radius
- Elevation
- Motion
- Icons

---

# Assets

Formats

- SVG
- PNG
- PDF

---

# Catalog Design Package

Claude Design delivery for the MVP catalog must include:

- Catalog Import
- Import Validation Results
- Draft Catalog
- Catalog Preview
- Category Ordering
- Product Ordering
- Product Editor
- Product Media Gallery
- Image Upload and Replacement
- Branch Availability
- Stop List
- Publish and Unpublish Confirmation
- Publish History

Required states:

- Empty catalog
- Draft
- Published
- Hidden product
- Branch Stop List
- Import validating, partially valid, failed and completed
- Image empty, uploading, processing, failed and ready
- Preview mode
- Publish success and failure

Required data coverage:

- real menu names, descriptions, weights and prices supplied by the Product Owner;
- long and short product names;
- missing and replacement images;
- products with Popular, New and Featured combinations;
- unavailable products and branch-specific Stop List;
- category and product ordering.

The design package specifies presentation and interaction only. API behavior remains governed by API-706, and product rules remain governed by PB-305.

---

# Developer Handoff

Required

- Measurements
- Colors
- Typography
- Constraints
- Exportable Assets
- Component Names
- Design Tokens

---

# Traceability

Each Screen

↓

User Journey

↓

Product Requirement

↓

API Endpoint

↓

Database Entity

---

# Versioning

Every delivery includes

- Version
- Date
- Author
- Change Log

---

# Acceptance Criteria

- Все экраны имеют спецификацию.
- Все компоненты используют Design Tokens.
- Все экраны связаны с Product Requirements.
- Все элементы имеют Accessibility Specification.
- Все ресурсы готовы к разработке Flutter.
- Все изменения проходят дизайн-ревью.
- Catalog screens cover every required lifecycle, import and media state.
- Catalog Preview is visually distinguishable from the public Customer App state.
- Back Office catalog operations are usable with keyboard navigation on Flutter Web.

---

# Related Documents

UI-802 Design System

UI-803 Component Library

PB-305 Product Requirements

API-701 API Overview

API-706 Menu & Product API

UI-805 Back Office UX

END OF DOCUMENT
