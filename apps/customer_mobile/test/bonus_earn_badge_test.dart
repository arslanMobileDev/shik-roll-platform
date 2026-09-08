import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/menu/view/widgets/product_details/product_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ролл за 390,00 ₽ без модификаторов: кешбэк 5% → floor(19,5) = 19 бонусов.
const _item = MenuItem(
  id: 'item-philadelphia',
  sku: 'R-001',
  name: 'Филадельфия',
  description: 'Лосось, сыр, огурец.',
  category: MenuItemCategoryRef(id: 'cat-rolls', name: 'Роллы'),
  price: Money.kopecks(39000),
  sortOrder: 0,
  isPopular: true,
  isNew: false,
  isHalal: true,
  available: true,
  modifierGroups: [],
);

Future<void> _pumpDetails(
  WidgetTester tester, {
  required double cashbackRate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<CustomerCartBloc>(
        create: (_) => CustomerCartBloc(),
        child: Scaffold(
          body: ProductDetailsView(item: _item, cashbackRate: cashbackRate),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('бейдж «+X бонусов при заказе» считается от ставки кешбэка', (
    tester,
  ) async {
    await _pumpDetails(tester, cashbackRate: 5);

    expect(find.byKey(const ValueKey('bonus-earn-badge')), findsOneWidget);
    expect(find.text('+19 бонусов при заказе'), findsOneWidget);
  });

  testWidgets('нулевая ставка: бейдж скрыт', (tester) async {
    await _pumpDetails(tester, cashbackRate: 0);

    expect(find.byKey(const ValueKey('bonus-earn-badge')), findsNothing);
  });
}
