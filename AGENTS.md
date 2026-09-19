# Repository Agent Instructions

## Scope

- Work only with the GitHub repository `arslanMobileDev/shik-roll-platform`.
- Treat the repository content as the source of truth.
- Treat `main` as the source branch for the original state.
- Perform documentation changes only in an explicitly designated working branch.
- Use `docs/ai-tooling-neutrality` as the current documentation QA branch until the project owner explicitly selects another branch.

## Change Authorization

Before changing repository content:

1. List every file that will be affected.
2. Describe the exact intended changes.
3. State the possible consequences.
4. Wait for explicit project-owner confirmation.

The project owner may explicitly waive the confirmation step for a named package. Such a waiver applies only to that package and does not carry over to later work.

Do not create or change files, branches, commits, issues, pull requests, releases, or other repository state without explicit authorization.

## Architecture Decisions

- Do not make architecture or product-scope decisions independently.
- When documents conflict, present the conflicting evidence, available options, consequences, and questions requiring the project owner's decision.
- Record only decisions explicitly accepted by the project owner.
- Treat accepted ADRs as authoritative within their documented scope.
- Do not allow navigation documents, summaries, or compatibility redirects to override governed documents.
- Treat AI models, providers, agent shells, and MCP tools as replaceable execution tools. They must not override repository requirements, accepted ADRs, or approved Figma design artifacts.

## Documentation Safety

- Do not delete or rename files without separate explicit permission.
- Do not change an existing Document ID without separate explicit permission.
- Do not perform mass formatting.
- Do not change content unrelated to the active package.
- Preserve compatibility paths unless the project owner explicitly approves their removal.
- Use canonical terminology from PB-109 Terminology Glossary.
- Keep the general Document Registry and ADR-1600 synchronized with governed documents.

## Package Completion

After every package:

1. List all changed files.
2. Summarize the semantic diff.
3. Recheck Document ID uniqueness.
4. Recheck Related Documents.
5. Recheck local Markdown links.
6. Run the repository documentation validation when available.
7. Report any commit created for the package; if no commit was authorized, state that no commit was created.
8. Stop until the next confirmation unless the project owner explicitly waived that pause for the package.

## Publishing

- Do not create a pull request without a separate explicit command.
- Do not merge, rebase, squash, force-push, or rewrite history without separate explicit permission.
- Never modify `main` directly during documentation QA.

## MCP Memory Server

Для агентов доступен MCP `agent-memory` — семантическая память проекта.

### Использование

- **Pre-Flight check:** перед началом работы вызови
  `memory_pitfalls(project_name="SHIK-ROLL-PLATFORM")` — увидишь уроки
  предыдущих сессий и правила, которых нельзя нарушать.
- **Post-Mortem:** после критической ошибки или зацикливания вызови
  `memory_save(project_name="SHIK-ROLL-PLATFORM", category="pitfalls_and_failures", content="1. Что сломалось. 2. Почему. 3. Жёсткое правило.")`.

### Инструменты

| Tool | Назначение |
|---|---|
| `memory_save` | Сохранить запись (project_name, category, content) |
| `memory_search` | Найти по проекту, категории, подстроке |
| `memory_pitfalls` | Уроки и грабли проекта |
| `memory_categories` | Список категорий |
| `memory_stats` | Статистика по проекту |

### Технические детали

- Бэкенд: PostgreSQL + pgvector на VPS Майами через autossh-туннель.
- Реализация: `~/.agent-memory-mcp/server.js` (5 tools, только SELECT и INSERT).
- DSN хранится в macOS Keychain (`agent-memory-postgres`).

### Категории (используемые)

- `pitfalls_and_failures` — уроки и грабли (Pre-Flight check)
- `testing_and_multer_gotchas` — особенности тестов
- `deployment_workflow` — деплой
- `roles_architecture`, `roles_engineering`, `roles_qa_audit` — роли агентов
- `routing_rules` — правила маршрутизации задач
- `infrastructure` — инфраструктура

### Правила

- Не удаляй записи через БД напрямую — только `memory_save`.
- Используй `pitfalls_and_failures` для уроков и грабель.
- Указывай `project_name="SHIK-ROLL-PLATFORM"` для этого проекта.
