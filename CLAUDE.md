# SHIK Platform — AI Guidelines

## Project Context
- Product: SHIK Platform (Cloud-native Restaurant OS), first brand: SHIK ROLL.
- Canonical Architecture: docs/05-architecture/501-system-overview.md (ARC-501).
- Frontend: Flutter (Mobile, POS, KDS, Back Office & Owner Dashboard via Flutter Web).
- Backend: NestJS (TypeScript), PostgreSQL (Prisma), Redis.
- Queues: BullMQ (background jobs), RabbitMQ (inter-service domain events).
- Storage: Provider-neutral Port/Adapter (MinIO for dev, GCS for prod).

## Related repositories (READ-ONLY from this workspace)

- **ai-brain** — knowledge base, lives at `~/Projects/ai-brain`
  (on disk: `~/Projects/AI-Brain`; filesystem is case-insensitive).
  - Architecture decisions: `~/Projects/ai-brain/02-Architecture-Decisions/`
  - Pitfalls: `~/Projects/ai-brain/06-AI-Agent-Pitfalls/`
  - Daily logs / handoffs: `~/Projects/ai-brain/00-Meta/`, `~/Projects/ai-brain/08-Daily-Log/`
  - Infra docs: `~/Projects/ai-brain/04-Infrastructure/`
  Read ADR/pitfall files with `Read ~/Projects/ai-brain/...`. Do not
  create new files there from this workspace — switch to that repo
  (cd ~/Projects/ai-brain) for writes.

- **dosterra-courier** — separate Flutter repo, at `~/Projects/dosterra-courier-repo`.

## Backend (services/backend)

- NestJS + Prisma + PostgreSQL (shik_menu for dev, shik_menu_test for e2e).
- Migrations: `npx prisma migrate deploy` (not `dev` in non-interactive).
- Pre-push hook runs e2e — do not bypass.
- Tests: `pnpm jest` (unit), `pnpm test:e2e` (e2e, --runInBand).
- `pnpm lint` (tsc) is mandatory AFTER every commit, on the committed tree:
  ts-jest runs with `isolatedModules` and does not typecheck, so a bad import
  silently becomes `undefined` at runtime and tests stay green. See agent-memory id=101.

## Language rules

- Code comments, commit messages: English.
- ADR / Pitfall / docs in ai-brain: Russian.
- Chat responses to me: Russian.

## Operational Rules
1. Work only in dedicated feature/qa branches, never touch main directly.
2. Read ONLY target files needed for the task; do not do full repository scans.
3. Keep changes atomic, minimal, and preserve document IDs and frontmatter.
4. Do not create commits, push branches, or open PRs without explicit confirmation.

## Conventions

- Never push to main directly — feature branches.
- Never commit .env, *.jks, secrets.
- Read existing code before editing; no invented APIs.
