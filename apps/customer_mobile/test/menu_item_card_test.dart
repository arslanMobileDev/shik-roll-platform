import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/menu/view/widgets/menu_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'menu_item_json_fixture.dart';

const _photoUrl = 'https://api.shik-roll.ru/uploads/menu/roll.webp';

/// ICU `ru_RU` separates both the digit groups and the currency symbol with a
/// non-breaking space (U+00A0), so expectations are written as readable prices
/// and swapped here.
String _rub(String readable) => readable.replaceAll(' ', ' ');

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

/// Mirrors the real grid cell: 198dp on the widest shipping phone (440dp
/// screen − 2×16 outer padding − 12 gutter, halved). That leaves 166dp of
/// card content — the constraint the price row has to survive.
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
          width: 198,
          height: 400,
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
    expect(find.text(item.price.formatCompact()), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
  });

  // The kopeck tail pushed «1 490,00 ₽» onto a second line inside 166dp; the
  // card now drops it when it is zero and keeps it when it is not.
  testWidgets('shows whole rubles, without the zero kopeck tail', (
    tester,
  ) async {
    await _pumpCard(tester, _item(priceKopecks: 149000));
    expect(find.text(_rub('1 490 ₽')), findsOneWidget);
    expect(find.text(_rub('1 490,00 ₽')), findsNothing);
  });

  testWidgets('keeps kopecks when the price actually has them', (
    tester,
  ) async {
    await _pumpCard(tester, _item(priceKopecks: 149050));
    expect(find.text(_rub('1 490,50 ₽')), findsOneWidget);
  });

  testWidgets('price is pinned to a single line next to the action button', (
    tester,
  ) async {
    await _pumpCard(tester, _item(priceKopecks: 149000));

    final price = tester.widget<Text>(find.text(_rub('1 490 ₽')));
    expect(price.maxLines, 1);
    expect(price.softWrap, isFalse);
    // The button label must not wrap either — it competes for the same row.
    expect(find.text('В корзину', findRichText: false), findsOneWidget);
  });

  testWidgets('hides HALAL badge when item is not halal', (tester) async {
    await _pumpCard(tester, _item(isHalal: false));
    expect(find.byIcon(Icons.verified_outlined), findsNothing);
  });

  testWidgets('renders the dish photo when the API sends imageUrl', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      MenuItem.fromJson(menuItemJson(imageUrl: _photoUrl)),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, _photoUrl);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('photo window is square (1:1), matching the 1000×1000 upload', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      MenuItem.fromJson(menuItemJson(imageUrl: _photoUrl)),
    );

    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, 1.0);
  });

  testWidgets('falls back to the placeholder icon without imageUrl', (
    tester,
  ) async {
    await _pumpCard(tester, MenuItem.fromJson(menuItemJson()));

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
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
