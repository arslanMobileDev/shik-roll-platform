---
Document ID: ADR-006
Document Name: Unified Communication Automation Center
Version: 1.0.0
Status: APPROVED
Project: SHIK Platform
Owner: Arslan Berslanov
Last Updated: July 2026
Classification: Internal
---

# ADR-006 — Unified Communication Automation Center

## Context

SHIK Platform должна отправлять клиентам, сотрудникам, управляющим и владельцам сообщения через различные каналы.

Поддерживаемые каналы:

- Push Notifications
- In-App Messages
- WhatsApp Business
- Telegram
- Email
- SMS
- Webhooks

Использование одного фиксированного канала ограничило бы владельца ресторана и создало зависимость от конкретного провайдера.

## Decision

Создать единый модуль Communication Automation Center.

Владелец или уполномоченный менеджер сможет через Back Office определять:

- какие события создают сообщения;
- каким получателям они отправляются;
- через какие каналы;
- с какой задержкой;
- с каким шаблоном;
- какие резервные каналы используются при недоставке;
- какие правила действуют для конкретного филиала.

## Decision Scope

ADR-006 фиксирует архитектурное решение о едином Communication Automation Center, независимом от каналов и провайдеров.

Канонические продуктовые требования, состав MVP, Phase 2, события, бизнес-правила и критерии приемки определяются в PB-306 Communication Automation Center.

Изменение продуктового объема PB-306 не отменяет ADR-006, пока сохраняются:

- единая точка управления коммуникациями;
- независимые адаптеры каналов и провайдеров;
- управление правилами и шаблонами;
- журналирование попыток доставки;
- учет согласий и пользовательских предпочтений.

## Consequences

### Positive

- владелец самостоятельно управляет коммуникациями;
- добавление нового канала не меняет бизнес-логику;
- возможны настройки по филиалам;
- появляется единая история коммуникаций;
- уменьшается зависимость от одного поставщика.

### Risks

- стоимость сообщений внешних провайдеров;
- требования к согласию пользователей;
- ограничения шаблонов WhatsApp Business;
- необходимость контроля повторных сообщений;
- риск отправки избыточного количества уведомлений.

## Related Documents

- PB-304 BUSINESS_CAPABILITIES
- PB-306 COMMUNICATION_AUTOMATION_CENTER
- RTM-001 REQUIREMENTS_TRACEABILITY_MATRIX
- PB-108 BUSINESS_RULES

END OF DOCUMENT