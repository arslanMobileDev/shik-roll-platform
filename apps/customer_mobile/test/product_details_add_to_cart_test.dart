import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/cart_state.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/menu/view/widgets/product_details/product_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plain dish without modifier groups: the add button must be enabled by
/// default (no required unselected modifiers) and the default quantity is 1.
final _item = MenuItem(
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
  modifierGroups: const [],
);

Finder _addButton() => find.byKey(const ValueKey('add-to-cart-button'));

/// Reproduces the production tree: [CustomerCartBloc] is provided below the
/// MaterialApp's Navigator (as in HomeShell), and the details sheet is
/// opened via [showProductDetails] as a modal route on top of it.
Future<void> _pumpMenuWithCart(
  WidgetTester tester,
  CustomerCartBloc cartBloc,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<CustomerCartBloc>.value(
        value: cartBloc,
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showProductDetails(context, _item),
                child: const Text('open-details'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'клик по «Добавить в корзину» в карточке товара добавляет товар '
    'в CustomerCartBloc, показывает SnackBar и закрывает модалку',
    (tester) async {
      final cartBloc = CustomerCartBloc();
      addTearDown(cartBloc.close);

      await _pumpMenuWithCart(tester, cartBloc);

      // Открываем карточку товара (bottom sheet).
      await tester.tap(find.text('open-details'));
      await tester.pumpAndSettle();
      expect(_addButton(), findsOneWidget);

      // Кнопка активна по умолчанию: обязательных модификаторов нет.
      final button = tester.widget<FilledButton>(_addButton());
      expect(button.onPressed, isNotNull);

      // Клик по кнопке «Добавить в корзину».
      await tester.tap(_addButton());
      await tester.pumpAndSettle();

      // Модальное окно закрыто.
      expect(_addButton(), findsNothing);

      // Показан SnackBar об успешном добавлении.
      expect(find.text('Добавлено в корзину'), findsOneWidget);

      // Товар появился в корзине одной позицией с количеством 1.
      final CartState cart = cartBloc.state;
      expect(cart.lines, hasLength(1));
      expect(cart.lines.single.item.id, _item.id);
      expect(cart.lines.single.quantity, 1);
      expect(cart.itemCount, 1);
      expect(cart.total, _item.price);
    },
  );
}
