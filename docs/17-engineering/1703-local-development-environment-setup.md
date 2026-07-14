---
Document ID: ENG-1703

Document Name: LOCAL DEVELOPMENT ENVIRONMENT SETUP

Book: Engineering Handbook

Version: 1.0.0

Status: APPROVED

Project: SHIK Platform

Owner: Arslan Berslanov

Solution Architect: OpenAI ChatGPT

Last Updated: July 2026

Classification: Internal
---

# LOCAL DEVELOPMENT ENVIRONMENT SETUP

## Purpose

Определяет стандартную локальную среду разработки SHIK Platform.

---

# Objectives

- Consistent Development Environment
- Fast Project Setup
- Reproducible Builds
- Developer Productivity

---

# Supported Operating Systems

- macOS
- Windows
- Linux

---

# Required Software

Development

- Git
- Docker Desktop
- Node.js LTS
- pnpm
- Flutter SDK

Editors

- Visual Studio Code

Mobile

- Android Studio
- Xcode (macOS)

Database Tools

- PostgreSQL Client

API Tools

- Postman
- Bruno

---

# Repository Setup

Steps

- Clone Repository
- Install Dependencies
- Install Git Hooks
- Configure Environment Variables
- Start Docker Services

---

# Backend Setup

Run

- Install Dependencies
- Generate Prisma Client
- Run Database Migrations
- Seed Database
- Start Development Server

Verify

- API Running
- Swagger Available
- Database Connected

---

# Frontend Setup

Run

- Install Dependencies
- Generate Localization Files
- Start Flutter Application

Verify

- Successful Build
- API Connectivity
- Authentication Flow

---

# Docker Services

Required

- PostgreSQL
- Redis
- RabbitMQ
- MinIO

Optional

- Prometheus
- Grafana
- Loki

---

# Environment Files

Required

- .env.local
- .env.development

Never Commit

- Production Secrets
- API Keys
- Private Certificates

---

# Development Workflow

- Pull Latest Changes
- Install Dependencies
- Apply Migrations
- Run Tests
- Start Services
- Develop
- Commit Changes

---

# Validation Checklist

Verify

- Docker Running
- Backend Running
- Frontend Running
- Database Connected
- Queue Connected
- Storage Available
- Tests Passing

---

# Troubleshooting

Common Issues

- Docker Not Running
- Port Conflicts
- Migration Errors
- Missing Environment Variables
- Dependency Version Mismatch

---

# Performance Recommendations

- Use SSD Storage
- Minimum 16 GB RAM
- Multi-Core CPU
- Enable Docker Resource Limits
- Use Local Build Cache

---

# Related Documents

ENG-1702 Developer Onboarding Guide

DEV-1205 Docker & Containerization

DEV-1206 Environment Configuration & Secrets Management

END OF DOCUMENT