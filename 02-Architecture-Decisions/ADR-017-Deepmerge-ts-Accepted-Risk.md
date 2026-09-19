---
type: architecture_decision_record
status: accepted
date: 2026-09-19
project: SHIK-ROLL-PLATFORM
tags:
  - architecture/security
  - risk/accepted
  - dependencies/transitive
---

# ADR-017: Принятие риска CVE в deepmerge-ts (транзитивная)

## Контекст

CodeInspectus с Trivy DB обнаружил HIGH-уязвимость `CWE-1395` в `deepmerge-ts@7.1.5`:
**stack exhaustion при merge рекурсивных объектных графов** (DoS).

Пакет — **транзитивная зависимость**:
- Идёт через `@prisma/config@6.19.3` → `deepmerge-ts@7.1.5`.
- Напрямую мы его не импортируем.
- Даже `@prisma/config@latest (7.10.0)` всё ещё требует `deepmerge-ts@7.1.5`.

## Почему это НЕ критично для нас

### 1. Не используется в runtime

`@prisma/config` — **внутренний пакет Prisma CLI**. Он работает только при выполнении:
- `prisma generate`
- `prisma migrate`
- `prisma db pull`

В **работающем NestJS-сервере** этот пакет **не загружается**. Он живёт исключительно в dev/build-окружении.

### 2. Нет вектора атаки

Stack exhaustion требует:
- Пользовательского ввода с **рекурсивными графами**.
- Передачи этого графа в `deepmerge-ts.merge()`.

У нас:
- Prisma конфиг — **статический** файл `schema.prisma`.
- Никакой пользовательский ввод туда не попадает.
- Merge рекурсивных объектов в CLI-командах не происходит.

### 3. Форсирование версии — рискованно

`pnpm.overrides.deepmerge-ts = ^8.0.2` — возможно, сломает Prisma CLI:
- API 8.x может отличаться от 7.x.
- `@prisma/config@6.19.3` не тестировался с 8.x.
- Цена ошибки — сломанные миграции и генерация клиента.

## Решение

**Принимаем риск.** Версию не форсируем.

### Обязательства

1. **Мониторить** обновления `@prisma/config` — при переходе на `deepmerge-ts >= 8.0` обновить Prisma.
2. **Перепроверять** при мажорном апгрейде Prisma (7 → 8, 8 → 9).
3. **Не использовать** `deepmerge-ts` напрямую в коде — если понадобится, брать 8.x.

### Альтернативы (отклонены)

| Альтернатива | Причина отклонения |
|---|---|
| **`pnpm.overrides.deepmerge-ts = ^8.0.2`** | Риск сломать Prisma CLI, несоразмерно риску |
| **Заморозить Prisma на текущей** | Уже текущая, обновления не помогают |
| **Удалить Prisma** | Абсурд — вся работа с БД на ней |

## Последствия

- ✅ Backend работает как раньше.
- ✅ Prisma CLI работает как раньше.
- ⚠️ `CodeInspectus scan --scanner vuln` продолжит показывать этот finding. Это **ожидаемое поведение** — в отчётах его игнорируем, зная контекст.
- 📌 При следующем `pnpm update @prisma/config` — проверить, ушёл ли deepmerge-ts 7.x.

## Связь

- CodeInspectus finding: `DeepmergeTS has stack exhaustion when merging recursive object graphs`
- CVE-класс: `CWE-1395`
- `pnpm-lock.yaml` — services/backend
- `THIRD_PARTY_LICENSES.md` — общий файл атрибуции
