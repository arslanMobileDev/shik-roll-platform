# SHIK ROLL Courier App (Internal Use Only)

Лёгкое служебное приложение курьера: забор заказов с кухни и подтверждение доставки.
Flutter, Android / PWA. State management — BLoC (Cubit).

## Запуск

```bash
# Fake-режим (демо-заказы SHIK ROLL, любой 4-значный PIN)
flutter run

# Против реального бэкенда
flutter run --dart-define=API_BASE_URL=https://api.shikroll.example
```

## API-контракт

| Метод | Endpoint | Тело | Ответ |
|---|---|---|---|
| POST | `/couriers/auth/pin` | `{pin, phone}` | `{token, courier:{id,name}}` |
| GET | `/couriers/orders/active?branchId=...` | — | `[{order}]` (READY + DELIVERING) |
| PATCH | `/orders/{id}/status` | `{status: DELIVERING\|COMPLETED, courierId}` | — |

`RemoteCourierRepository` (Dio) и `FakeCourierRepository` реализуют
единый `CourierRepository` (`lib/data/repositories/`).

## Структура

```
lib/
  core/            тема SHIK ROLL (#FF5722, light/dark), Halal badge,
                   CourierAuthStorage (SharedPreferences), url_launcher helpers
  data/            модели (CourierOrder, CourierSession, Branch), репозитории
  features/auth/   вход по PIN + телефону, выбор филиала
  features/orders/ вкладки «К забору с кухни» (READY) / «Мои текущие» (DELIVERING),
                   карточка заказа, «Забрал заказ» / «Доставлено» (с подтверждением)
```

## Проверки

```bash
flutter analyze   # 0 issues
flutter test      # 19 тестов
flutter build apk --debug
flutter build web --release
```
