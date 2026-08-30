# SHIK POS (apps/pos)

Кассовый интерфейс SHIK Platform (UI-806 POS UX) на Flutter, построенный по
дизайн-системе UI-802/UI-803 и контракту Menu & Product API
(`services/backend/openapi.json`, API-706 / DB-607 v1.2.0 / BE-906).

## Возможности

- Каталог опубликованных позиций (`status: PUBLISHED`) с динамической
  подгрузкой страниц при прокрутке.
- Фильтры: категории, поиск по названию/SKU/составу, фильтр «Халяль».
- Бейджи состояния: HALAL, стоп-лист (с причиной), недоступность на филиале.
- Дерево модификаторов (типы WEIGHT / PORTION / ADDON / SAUCE):
  SINGLE/MULTIPLE-группы, обязательные группы, лимиты `maxSelected`.
- Корзина с точным расчётом сумм в RUB (integer minor units, без потерь
  точности), объединение одинаковых конфигураций позиций.
- Режимы заказа «В зале» / «Навынос» с выбором стола.
- Desktop-first: основная раскладка от 1280 px, рабочий минимум 1024 px,
  планшетная адаптация ниже (корзина через bottom sheet).

## Запуск

```sh
flutter pub get
# Демо-каталог в памяти (без бэкенда):
flutter run -d macos
# Против реального Menu & Product API:
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:3000 \
  --dart-define=BRAND_ID=<uuid> --dart-define=BRANCH_ID=<uuid>
```

## Проверки

```sh
flutter analyze
flutter test
```

## Архитектура

- `lib/core` — дизайн-токены UI-802, тема, `Money` (точная десятичная
  арифметика), API-клиент (dio), общие виджеты (бейджи, состояния, селекторы).
- `lib/features/catalog` — модели по openapi.json, `CatalogRepository`
  (remote + in-memory demo), `CatalogBloc`, виджеты UI-803
  (`CategorySortableList`, `MenuItemCard`, `ModifierTreeSelector`).
- `lib/features/cart` — `CartBloc`, строки корзины, `CartPanel`.
- `lib/features/tables` — `OrderModeCubit`, переключатель режимов.
- `lib/features/cashier` — композиция экрана кассира.

Управление состоянием — только BLoC (ADR-1606). Бизнес-логика живёт в
bloc/cubit, виджеты остаются презентационными.
