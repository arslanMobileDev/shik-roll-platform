import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/menu/view/widgets/menu_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MenuItem _item({
  String name = 'Филадельфия',
  int priceKopecks = 39000,
  bool isHalal = true,
  List<ModifierGroup> modifierGroups = const [],
}) {
  return MenuItem(
    id: 'item-1',
    sku: 'R-001',
    name: name,
    description: 'Лосось, сыр, огурец.',
    category: const MenuItemCategoryRef(id: 'cat-rolls', name: 'Роллы'),
    price: Money.kopecks(priceKopecks),
    sortOrder: 0,
    isPopular: true,
    isNew: false,
    isHalal: isHalal,
    available: true,
    modifierGroups: modifierGroups,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  MenuItem item, {
  VoidCallback? onAddToCart,
  VoidCallback? onSelect,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 320,
          child: MenuItemCard(
            item: item,
            onAddToCart: onAddToCart ?? () {},
            onSelect: onSelect ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows name, price and compact HALAL badge', (tester) async {
    final item = _item(isHalal: true);
    await _pumpCard(tester, item);

    expect(find.text('Филадельфия'), findsOneWidget);
    expect(find.text(item.price.format()), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
  });

  testWidgets('hides HALAL badge when item is not halal', (tester) async {
    await _pumpCard(tester, _item(isHalal: false));
    expect(find.byIcon(Icons.verified_outlined), findsNothing);
  });

  testWidgets('plain dish offers «В корзину» and calls onAddToCart', (
    tester,
  ) async {
    var added = 0;
    await _pumpCard(
      tester,
      _item(),
      onAddToCart: () => added++,
    );
    expect(find.text('В корзину'), findsOneWidget);
    await tester.tap(find.text('В корзину'));
    expect(added, 1);
  });

  testWidgets('modifier-bearing dish shows «Выбрать» and opens details', (
    tester,
  ) async {
    var opened = 0;
    const group = ModifierGroup(
      id: 'mg-sauce',
      name: 'Соусы',
      selectionType: ModifierSelectionType.single,
      minSelected: 0,
      isRequired: false,
      sortOrder: 0,
      items: [
        ModifierItem(
          id: 'mi-spicy',
          name: 'Спайси',
          price: Money.kopecks(4000),
          sortOrder: 0,
        ),
      ],
    );
    await _pumpCard(
      tester,
      _item(modifierGroups: [group]),
      onSelect: () => opened++,
    );
    expect(find.text('Выбрать'), findsOneWidget);
    await tester.tap(find.text('Выбрать'));
    expect(opened, 1);
  });
}
