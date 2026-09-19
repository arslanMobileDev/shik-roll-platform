# SESSION-HISTORY — SHIK ROLL Platform

Краткая история сессий. Заполняется в конце рабочего дня, 5 минут.
Цель: любой агент (ChatGPT, Kimi, DeepSeek) и любой разработчик
восстанавливает контекст без чтения всей переписки.

Правила:
- Одна запись = один день.
- Только ключевое: что сделано, решения, открытые вопросы, следующий шаг.
- Не дублировать git log — только смысл.
- Не хранить секреты, пароли, ключи.

---

## 2026-09-19

### Security-фиксы (5 findings закрыты)
- **Docker root:** nginx → nginxinc/nginx-unprivileged:1.27-alpine, порт 8080.
- **SharedPreferences токен:** → FlutterSecureStorage (WebCrypto/Keychain/EncryptedSharedPreferences) + lazy migration.
- **LGPL sharp:** ADR-016 + THIRD_PARTY_LICENSES.md (10 платформ libvips).
- **multer CVE (3 шт):** pnpm.overrides.multer = ^2.4.0.
- **deepmerge-ts CVE:** ADR-017 (accepted risk, используется только Prisma CLI).
- Все 5 в main (коммит 445554d). Тесты: 541 backend + 127 back-office зелёные.

### Инфраструктура агентов
- **CodeInspectus 3.2.0** + Trivy DB (1.3 ГБ): установлен, движки через curl (Node fetch не работал).
- **DSH (DeepSeek Harness) 0.1.5-rc.2** развёрнут: `npx @deepseek-ai/dsh web`.
- **dsh-mcp-manager 0.6.0** установлен через `pnpm add -w` + `cordis.patch.yml`.

### Claude Code (финальное состояние)
- **10 MCP, 100 tools:** agent-memory (5), ai-router (4), code-guard (3),
  codeinspectus (7), context7 (2), drawio (7), github (26), obsidian-vault (14),
  playwright (25), timeweb (7).
- **Модель:** DeepSeek V4 Flash (~/.claude/settings.json: `anthropic/deepseek/deepseek-v4-flash`).
  Переключена с Kimi K3 для экономии (в 3.3 раза дешевле).

### DSH (DeepSeek Harness)
- **Провайдеры:** DeepSeek напрямую (баланс 0, не используется) + OpenRouter (рабочий).
- **Модели через OpenRouter:** deepseek-chat, deepseek-v4-flash, gpt-5.6-luna,
  glm-5.3-flash, kimi-k3.
- **9 MCP подключено:** agent-memory, obsidian-vault, ai-router, timeweb, playwright,
  drawio, codeinspectus, code-guard, context7 (74 tools).

### ai-router-mcp расширен
- Добавлены `ask_gpt` (openai/gpt-5.6-luna) и `ask_glm` (z-ai/glm-5.3-flash).
- Итого 4 tools: ask_deepseek, ask_llama, ask_gpt, ask_glm.

### Ключи (все в Bitwarden + macOS Keychain)
- deepseek, openrouter, context7, agent-memory-postgres.
- ai-router-mcp/server.mjs: убран хардкод, читает `process.env.OPENROUTER_API_KEY`.
- openrouter key: отозван старый (утечка), создан новый, перенесён в Keychain.

### Бэкап инфраструктуры
- `~/Backups/agents-20260919/` (248 KB) + копия в iCloud.
- Состав: claude.json.backup, ai-router-mcp/, agent-memory-mcp/, vault.bundle,
  ssh-config.backup, com.user.postgres-tunnel.plist, keychain-items.txt.
- Секретов в бэкапе нет.

### Бюджет OpenRouter
- Баланс: **$8.70** (было $11.25).
- Kimi K3 съел $2.43 за 3.21M токенов (77 запросов) — 95% расхода.
- После переключения на DeepSeek V4 Flash расход снижен в 3.3 раза.

### Обнаружено (не решено)
- **Конфликт ADR:** в репе `02-Architecture-Decisions/` есть 3 ADR
  (ADR-001-BLoC, ADR-004-Cart-Money, ADR-008-Image-Optimization),
  в vault AI-Brain — 14 других ADR (ADR-002…ADR-015). Номера 004 и 008 заняты разными решениями.
- Требуется решение: где источник истины для ADR (репа/vault/гибрид).

### Решения
- MCP памяти — свой `agent-memory`, а не готовый пакет (готовые не работают с нашей схемой).
- DSH-клиент: используем DeepSeek V4 Flash для повседневки, Kimi K3 — точечно для сложных.
- DeepSeek напрямую (без OpenRouter) — отложено (баланс 0, российские карты не проходят).
- Этап C (gascity) — отложен на свежую голову.
- ADR конфликт — отложен, отдельной задачей.

### Следующий шаг
- Обкатать связку Claude Code + DSH на реальной задаче (P1 realtime или A.2b).
- Пополнить OpenRouter ($10-20) — решить в течение 2-3 дней.
- Этап C (gascity) — после обкатки текущего.

---
## 2026-09-18

### Сделано
- Отозваны старые ключи: GitHub PAT, OpenRouter, Context7 (когда заработает).
- Созданы новые ключи → Bitwarden.
- PostgreSQL: пароль сменён, старый не работает; `pg_hba.conf` → `scram-sha-256`
  для TCP, socket trust для recovery; `.env` с правами 600.
- Swap 4 GB на VPS Майами (`/swapfile`).
- Vault AI-Brain перенесён из `~/Documents` в `~/Projects` (TCC-проблема), git init (30 файлов).
- `~/.claude.json`: обновлены пароли, пути, удалён `gemini`.
- OpenRouter key перенесён в macOS Keychain (`security find-generic-password -s openrouter`).
- Autossh Mac → Майами как LaunchAgent, автоперезапуск (закрыт 17.09).

### Решения
- Ключи хранить только в Bitwarden + macOS Keychain. В файлах — не хранить.
- Все MCP, которые требуют секретов — читать их из Keychain, не из env.

### Следующий шаг (закрыт 19.09)
- Этап 2: базовый MCP-слой.

## 2026-09-17

### Сделано
- Задача 22 A.0 (backend): MenuItem.imageUrl + allergens, миграция, DTO,
  entity, mapper, repository, тесты. Пакет принят.
- Смена PIN KDS-01.
- Проверка «Курьеры» в back-office — работает.

### Решения
- Курьерское приложение: публикация через Google Play (Internal testing),
  iOS — через Apple Business Manager / Custom Apps или TestFlight.
- Ребрендинг курьерского приложения: переезд на собственное имя,
  мульти-инстанс архитектура (один код → N ресторанов, хостит владелец).
- Аллергены: минимальная реализация (String? в MenuItem) вместо
  структурированной модели — до релиза.
- AI-Brain (задачи 20–27): после релиза. SESSION-HISTORY.md — сейчас.

### Открытые вопросы
- Мульти-инстанс: как курьер находит свой бэкенд — выбор из списка,
  авто по номеру телефона, или комбинация.
- Клиентское приложение: одно с выбором ресторана или N брендированных сборок.
- Имя и домен для нового курьерского приложения.

### Инцидент / расследование
- Back-office «Создать блюдо» → 401 TOKEN_INVALID. Причина: staff JWT (12h)
  просрочен. После Clear site data + login → 400.
- 400 — расхождение контракта: frontend шлёт {category: enum, price: {rubles}},
  backend ждёт {categoryId: UUID, sku, basePrice}. Pre-existing долг.
- Решение: задача 22 A.2 (фикс маппинга, отдельное ТЗ ChatGPT).
- Деплой A.1 отложен до готовности A.2 (иначе кнопка «Создать» даёт 400).

### Следующий шаг
- Задача 22 A.1 (Upload UI в back_office) — ChatGPT в работе.
- После A.1 → A.2 → общий деплой.
- Параллельно: T2–T5 (терминалы, безопасность), задача 8 (keystore).

---

## 2026-09-16

### Сделано
- Задача 18 (Couriers CRUD) задеплоена.
- Раздел «Курьеры» добавлен в back-office.
- Смена PIN KDS-01 — не выполнена (перенесено на 17.09).
- Отзыв курьерских токенов — проверено: нечего отзывать.

### Решения
- Пропорция фото блюд: 1:1 (подтверждено референсами).
- Курьерские и клиентские приложения: публикация через сторы, не APK.
- Оплата за сторы ($25 + $99) — после готовности всех позиций.

### Открытые вопросы
- SMS-согласование SHIK-ROLLRU (ждём Т2, СберМобайл).
- DEV_OTP=true — выключить после интеграции SMS.ru.

### Следующий шаг
- Задача 22 (фото блюд) — 3 секции в ChatGPT.
- Задачи 6, 7 — выполнить.
