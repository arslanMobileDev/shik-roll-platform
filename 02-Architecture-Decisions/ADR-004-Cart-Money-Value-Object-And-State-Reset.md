---
id: ADR-004
title: Корзина — Money Value Object и семантика сброса nullable-полей в State
status: accepted
date: 2026-09-11
tags: [flutter, bloc, cart, money, value-object, adr]
---

# ADR-004: Корзина — Money VO и сброс nullable-полей в State

> Архитектурные решения гостевой корзины `apps/customer_mobile`: денежные вычисления через Value Object `Money`, производные (не хранимые) итоги и явный протокол сброса nullable-полей в `CartState.copyWith`. Реализовано в ветке `feat/customer-mobile-cart` (коммит `d4efbdf`).

## Контекст

Гостевая корзина (`CustomerCartBloc` + `CartLine` + `CartScreen`) уже существовала и была интегрирована в меню, шелл и чекаут. При расширении фичи потребовалось зафиксировать три правила, чтобы состояние корзины не деградировало по мере роста: как считать деньги, как хранить итоги и как работать с nullable-полями (`errorMessage`, в перспективе — промокод).

## Решение 1: Деньги — только через Money Value Object

**Проблема:** `double` для цен даёт бинарную погрешность при суммировании позиций и модификаторов (`0.1 + 0.2 != 0.3`) — итог корзины «плывёт» на копейки.

**Решение:** все суммы в корзине — `Money` (`lib/core/utils/money.dart`), хранящий целые копейки (`minorUnits`):

```dart
final class Money extends Equatable implements Comparable<Money> {
  const Money.kopecks(this.minorUnits);
  factory Money.fromRubles(num rubles) => Money.kopecks((rubles * 100).round());
  static const Money zero = Money.kopecks(0);

  Money operator +(Money other) => Money.kopecks(minorUnits + other.minorUnits);
  Money operator -(Money other) => Money.kopecks(minorUnits - other.minorUnits);
  Money operator *(int quantity) => Money.kopecks(minorUnits * quantity);

  String format({String locale = 'ru_RU', String symbol = '₽'}) { ... }
}
```

- Арифметика целочисленная — погрешность исключена по построению.
- `double` допустим только на границах: парсинг API (`fromRubles`) и отображение (`rubles` внутри `format()`).
- `Equatable` + `Comparable` дают сравнение в тестах и сортировку без ручных обёрток.

## Решение 2: Итоги — производные, не хранимые

`CartState` хранит только источник истины (`lines`, `deliveryFee`, `errorMessage`); все суммы вычисляются геттерами:

```dart
int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
Money get total => lines.fold(Money.zero, (sum, line) => sum + line.total);
Money get finalAmount => total + deliveryFee;
```

Хранить `total` полем запрещено: денормализованное значение неизбежно расходится с `lines` при любой забытой мутации. Каждый `emit` строит новый `CartState`, поэтому пересчёт в геттере бесплатен.

## Решение 3: Nullable-поля — явный флаг сброса (clearError)

**Проблема:** канонический `copyWith` со слепым fallback не умеет отличать «не трогать поле» от «сбросить в null»:

```dart
// АНТИПАТТЕРН: errorMessage невозможно сбросить — null «проваливается» в this.errorMessage
errorMessage: errorMessage ?? this.errorMessage,
```

**Решение:** для каждого nullable-поля в State — явный флаг очистки:

```dart
CartState copyWith({
  List<CartLine>? lines,
  Money? deliveryFee,
  String? errorMessage,
  bool clearError = false,
}) {
  return CartState(
    lines: lines ?? this.lines,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}
```

Семантика трёх состояний:

| Вызов | Результат |
| --- | --- |
| `copyWith()` / `copyWith(errorMessage: null)` | прежняя ошибка сохраняется |
| `copyWith(errorMessage: '...')` | ошибка заменяется |
| `copyWith(clearError: true)` | ошибка сбрасывается в `null` (побеждает одновременно переданное значение) |

**Граница ответственности:** `errorMessage` в `CartState` — только для сбоев уровня корзины (отклонённый промокод, протухшая позиция). Ошибки оформления заказа остаются в `CheckoutCubit` на sealed-состояниях ([[ADR-001-BLoC-Checkout-Resilience]]), дублировать их в корзине запрещено.

**Инвариант блока:** любая успешная мутация позиций (`CartItemAdded`, `CartLineQuantityChanged`, `CartLineRemoved`) эмитит `copyWith(clearError: true)` — пользователь, изменивший корзину, не видит протухшую ошибку. `CartCleared` — полный ресет в `const CartState()`.

## Последствия

- **+** Копеечная точность итогов гарантирована типом, а не дисциплиной.
- **+** Итоги не могут рассинхронизироваться с позициями — источник истины один.
- **+** Сброс nullable-полей — компилируемая операция с тестируемой семантикой, а не договорённость.
- **−** Каждое новое nullable-поле State требует своего `clearX`-флага — copyWith растёт; при числе таких полей > 3 рассмотреть sealed-состояния по образцу [[ADR-001-BLoC-Checkout-Resilience]].
- **−** `Money` не сериализуется напрямую в JSON API — конвертация `fromRubles`/`rubles` на границах репозиториев.

## Критерии приёмки

1. `finalAmount == total + deliveryFee`, в том числе для пустой корзины (`finalAmount == deliveryFee`).
2. `copyWith(errorMessage: null)` сохраняет прежнюю ошибку; `copyWith(clearError: true)` сбрасывает её; флаг побеждает одновременно переданное значение.
3. `deliveryFee` переживает мутации позиций; `CartCleared` обнуляет и ошибку, и доставку.
4. Покрыто `test/cart_bloc_test.dart` (10 тестов); полный suite `customer_mobile` — 204/204 зелёные.
