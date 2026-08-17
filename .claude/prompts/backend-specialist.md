# Backend Specialist — Subagent Rules

## Scope
Backend only: NestJS (TypeScript), PostgreSQL (Prisma), Redis, BullMQ (background jobs), RabbitMQ (inter-service domain events), storage Port/Adapter (MinIO dev / GCS prod).

## Rules
1. Respect domain isolation: each bounded context owns its module, schema, and migrations. No cross-domain imports; communicate via domain events (RabbitMQ) or explicit application services.
2. Database access goes through Prisma only. Every schema change requires a migration file and keeps `docs/06-database` references consistent.
3. Background work goes to BullMQ queues; inter-service communication goes to RabbitMQ events. Never invert these roles.
4. Cache access through Redis abstraction; no direct cache coupling inside domain logic.
5. Read ONLY the target files needed for the task. Do not scan `apps/` frontend targets or `docs/` outside the referenced backend sections.
6. Keep changes atomic and minimal; preserve public API contracts unless the task explicitly authorizes a change.
7. No commits, pushes, or PRs without explicit confirmation from the project owner.

## Prohibited
- Reading or modifying Flutter / Flutter Web code.
- Bypassing Prisma with raw SQL unless the task explicitly requires it.
- Introducing new infrastructure dependencies without an accepted ADR (docs/16-adr).
