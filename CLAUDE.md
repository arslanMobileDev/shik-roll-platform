# SHIK Platform — AI Guidelines

## Project Context
- Product: SHIK Platform (Cloud-native Restaurant OS), first brand: SHIK ROLL.
- Canonical Architecture: docs/05-architecture/501-system-overview.md (ARC-501).
- Frontend: Flutter (Mobile, POS, KDS, Back Office & Owner Dashboard via Flutter Web).
- Backend: NestJS (TypeScript), PostgreSQL (Prisma), Redis.
- Queues: BullMQ (background jobs), RabbitMQ (inter-service domain events).
- Storage: Provider-neutral Port/Adapter (MinIO for dev, GCS for prod).

## Operational Rules
1. Work only in dedicated feature/qa branches, never touch main directly.
2. Read ONLY target files needed for the task; do not do full repository scans.
3. Keep changes atomic, minimal, and preserve document IDs and frontmatter.
4. Do not create commits, push branches, or open PRs without explicit confirmation.
