---
id: ADR-001
title: BLoC Checkout Resilience — аудит архитектурных ошибок
status: accepted
date: 2026-09-10
source: ai-router / ask_gemini (Gemini Flash)
tags: [flutter, bloc, checkout, network-resilience, adr]
---

# ADR-001: BLoC Checkout Resilience

> Выжимка внешнего аудита: 3 главные архитектурные ошибки во Flutter BLoC при обработке состояний чекаута и сетевых сбоев. Контекст: платёжный флоу SHIK ROLL (YooKassa), KDS с SSE.

## Ошибка 1: «Плоское» состояние BLoC (Flat State Anti-pattern)

**Суть:** один класс `CheckoutState` с множеством nullable-полей-флагов (`isLoading`, `errorMessage`, `isSuccess`...) вместо разделения фаз жизненного цикла.

**Последствия:**
- Невозможные состояния (`isLoading == true` + `errorMessage != null` одновременно) — лоадер поверх ошибки.
- При retry забывают обнулить `errorMessage` — UI показывает протухшую ошибку.
- `build` экрана вырождается в спагетти из `if-else`.

**Решение — Sealed Classes (Dart 3):**

```dart
sealed class CheckoutState {}

class CheckoutInitial extends CheckoutState {}
class CheckoutLoading extends CheckoutState {}
class CheckoutFailure extends CheckoutState {
  final NetworkException exception;
  CheckoutFailure(this.exception);
}
class CheckoutSuccess extends CheckoutState {
  final Order order;
  CheckoutSuccess(this.order);
}
```

UI рендерится через `switch` по состояниям; невозможные комбинации исключены на уровне компилятора.

## Ошибка 2: Состояния для одноразовых событий (Side Effects)

**Суть:** навигация (экран успешной оплаты) и SnackBar об ошибке сети эмитятся как состояния BLoC.

**Последствия:**
- Повторное срабатывание при повороте экрана / сворачивании приложения / переподписке на Stream — пользователя снова кидает на экран успеха, SnackBar всплывает повторно.
- Навигация — действие, а не состояние системы; история состояний засоряется.

**Решение — разделение State и One-time Effects:**
- **Вариант А:** `BlocListener` реагирует на навигацию только при переходе в терминальное состояние (`CheckoutSuccess`).
- **Вариант Б:** отдельный стрим эффектов внутри BLoC:

```dart
final _effectsController = StreamController<CheckoutEffect>();
Stream<CheckoutEffect> get effects => _effectsController.stream;

void _onPay(PayEvent event, Emitter emit) async {
  try {
    // ... оплата
  } catch (e) {
    _effectsController.add(ShowSnackBarEffect("Проблемы со связью"));
  }
}
```

## Ошибка 3: Игнорирование конкурентности (Race Conditions / Double Tap)

**Суть:** `on<Event>` по умолчанию конкурентен. Пользователь жмёт «Оплатить» несколько раз при медленной сети → параллельные запросы.

**Последствия:**
- Двойное списание средств (два запроса на транзакцию).
- Хаос в UI: `Loading → Success → Failure → Success` из-за race condition.

**Решение — Event Transformers (`bloc_concurrency`):**

```dart
import 'package:bloc_concurrency/bloc_concurrency.dart';

on<CheckoutSubmitOrder>(
  _onSubmitOrder,
  transformer: droppable(), // игнорирует новые события, пока работает обработчик
);
```

Для транзакций чекаута `droppable()` — единственный безопасный выбор (`restartable()` допустим для поиска, но не для платежей).

## Решение (Decision)

Для checkout-флоу SHIK ROLL принять три правила:
1. Состояния чекаута — только `sealed class`, без nullable-флагов.
2. Навигация и SnackBar — через `BlocListener` / отдельный стрим эффектов, не через State.
3. Submit-события оплаты — строго с `transformer: droppable()`.

## Последствия (Consequences)

- **+** Исключены невозможные состояния и двойные транзакции на уровне архитектуры.
- **+** Предсказуемое поведение UI при сетевых сбоях и поворотах экрана.
- **−** Требуется рефакторинг существующих BLoC чекаута; дополнительная зависимость `bloc_concurrency`.
