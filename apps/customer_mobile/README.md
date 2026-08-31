# SHIK Customer Mobile App

Guest-facing mobile app (iOS / Android) for the SHIK ROLL brand: menu
showcase, product details with modifiers, cart counter placeholder.

## Run

```bash
flutter run
```

Uses the in-memory demo menu (`FakeCustomerMenuRepository`) by default. To
talk to the Menu & Product API (API-706):

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Check

```bash
flutter pub get
flutter analyze
flutter test
```

## Architecture

- `lib/core` — UI-802/UI-803 design tokens (colors / typography / spacing /
  radius), shared widgets (`HalalStatusBadge`), `Money`, `ApiClient` (Dio).
- `lib/features/menu` — `MenuBloc` (Loading / Loaded / Error), category
  ribbon, order-type toggle (Доставка / Самовывоз), product card and the
  details sheet (`ProductDetailsCubit` does modifier selection + total
  recalculation).
- `lib/features/cart` — `CartCountCubit` (badge counter; full cart feature
  lands with checkout).
- `lib/features/shell` — bottom navigation scaffold (Меню, Корзина, Заказы,
  Профиль) wired to portrait-safe mobile layout.
