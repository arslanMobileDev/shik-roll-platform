# Third-Party Licenses

Проект **SHIK ROLL Platform** использует следующие сторонние библиотеки под лицензиями, требующими атрибуции. Файл ведётся вручную и обновляется при добавлении новых LGPL/GPL-зависимостей.

---

## LGPL-3.0-or-later

### libvips (через `@img/sharp-libvips-*`)

- **Пакеты:**
  - `@img/sharp-libvips-darwin-arm64`
  - `@img/sharp-libvips-darwin-x64`
  - `@img/sharp-libvips-linux-x64`
  - `@img/sharp-libvips-linux-arm64`
  - `@img/sharp-libvips-win32-x64`
- **Лицензия:** LGPL-3.0-or-later
- **Использование:** обработка и оптимизация изображений меню (ресайз, кроп, конвертация в WebP). См. ADR-008 `Sharp-Uploads-Pipeline`.
- **Способ связывания:** динамическая линковка через npm-пакет `sharp`.
- **Исходный код libvips:** https://github.com/libvips/libvips
- **Текст лицензии:** https://www.gnu.org/licenses/lgpl-3.0.txt

**Заявление об использовании:**

- libvips **не модифицирован**. Используется как готовая динамическая библиотека, распространяемая через `sharp`.
- Динамическая линковка сохраняет закрытость исходного кода SHIK ROLL Platform.
- Обязательства LGPL-3.0-or-later выполнены:
  1. Исходный код libvips доступен по ссылке выше.
  2. Настоящий файл уведомляет пользователей об использовании LGPL-компонента.
  3. libvips не является производной от кода SHIK ROLL Platform.
- Решение зафиксировано в `02-Architecture-Decisions/ADR-016-LGPL-Sharp.md`.

---

## Поддержка

При добавлении новых зависимостей с лицензиями LGPL/GPL/AGPL — обновить этот файл. Проверка выполняется через CodeInspectus (`--scanner license`).
