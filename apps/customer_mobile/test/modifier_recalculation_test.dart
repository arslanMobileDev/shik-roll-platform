import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/menu/view/widgets/product_details/product_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Portion group: required single-choice (пре-selected «Стандарт»).
/// Sauce group: optional multiple-choice.
final _item = () {
  const portionGroup = ModifierGroup(
    id: 'mg-portion',
    name: 'Порция',
    selectionType: ModifierSelectionType.single,
    minSelected: 1,
    maxSelected: 1,
    isRequired: true,
    sortOrder: 0,
    items: [
      ModifierItem(
        id: 'mi-p-std',
        name: 'Стандарт',
        price: Money.zero,
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-p-lg',
        name: 'Большая',
        price: Money.kopecks(15000),
        sortOrder: 1,
      ),
    ],
  );
  const sauceGroup = ModifierGroup(
    id: 'mg-sauce',
    name: 'Соусы',
    selectionType: ModifierSelectionType.multiple,
    minSelected: 0,
    maxSelected: 2,
    isRequired: false,
    sortOrder: 1,
    items: [
      ModifierItem(
        id: 'mi-s-spicy',
        name: 'Спайси',
        price: Money.kopecks(4000),
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-s-unagi',
        name: 'Унаги',
        price: Money.kopecks(4000),
        sortOrder: 1,
      ),
    ],
  );
  return MenuItem(
    id: 'item-philadelphia',
    sku: 'R-001',
    name: 'Филадельфия',
    description: 'Лосось, сыр, огурец.',
    category: const MenuItemCategoryRef(id: 'cat-rolls', name: 'Роллы'),
    price: const Money.kopecks(39000),
    sortOrder: 0,
    isPopular: true,
    isNew: false,
    isHalal: true,
    available: true,
    modifierGroups: const [portionGroup, sauceGroup],
  );
}();

String _buttonLabel(Money total) => 'Добавить в корзину за ${total.format()}';

Finder _button() => find.byKey(const ValueKey('add-to-cart-button'));

void main() {
  testWidgets('initial total = базовая цена: 390,00 ₽, кнопка активна', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CustomerCartBloc>(
          create: (_) => CustomerCartBloc(),
          child: Scaffold(body: ProductDetailsView(item: _item)),
        ),
      ),
    );

    expect(find.text('Филадельфия'), findsOneWidget);
    expect(find.text(_buttonLabel(const Money.kopecks(39000))), findsOneWidget);

    final enabled = tester.widget<FilledButton>(_button()).onPressed != null;
    expect(enabled, isTrue);
  });

  testWidgets('меняет итог при выборе порции/соуса и обратном отключении', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CustomerCartBloc>(
          create: (_) => CustomerCartBloc(),
          child: Scaffold(body: ProductDetailsView(item: _item)),
        ),
      ),
    );

    // Выбираем большую порцию: +150 ₽.
    await tester.tap(find.text('Большая'));
    await tester.pump();
    expect(
      find.text(_buttonLabel(const Money.kopecks(39000 + 15000))),
      findsOneWidget,
    );

    // Добавляем соус «Спайси»: ещё +40 ₽.
    await tester.tap(find.text('Спайси'), warnIfMissed: false);
    await tester.pump();
    expect(
      find.text(_buttonLabel(const Money.kopecks(39000 + 15000 + 4000))),
      findsOneWidget,
    );

    // Снимаем соус: −40 ₽.
    await tester.tap(find.text('Спайси'), warnIfMissed: false);
    await tester.pump();
    expect(
      find.text(_buttonLabel(const Money.kopecks(39000 + 15000))),
      findsOneWidget,
    );
  });
}
