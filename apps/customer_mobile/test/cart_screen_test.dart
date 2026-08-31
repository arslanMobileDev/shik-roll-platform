import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/cart_event.dart';
import 'package:customer_mobile/features/cart/bloc/checkout_cubit.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/cart/data/fake_orders_repository.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/cart/view/cart_screen.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _roll = () {
  const sauceGroup = ModifierGroup(
    id: 'mg-sauce',
    name: 'Соусы',
    selectionType: ModifierSelectionType.multiple,
    minSelected: 0,
    maxSelected: 2,
    isRequired: false,
    sortOrder: 0,
    items: [
      ModifierItem(
        id: 'mi-s-spicy',
        name: 'Спайси',
        price: Money.kopecks(4000),
        sortOrder: 0,
      ),
    ],
  );
  return MenuItem(
    id: 'item-philadelphia',
    sku: 'R-001',
    name: 'Филадельфия',
    category: const MenuItemCategoryRef(id: 'cat-rolls', name: 'Роллы'),
    price: const Money.kopecks(39000),
    sortOrder: 0,
    isPopular: true,
    isNew: false,
    isHalal: true,
    available: true,
    modifierGroups: const [sauceGroup],
  );
}();

const _drink = MenuItem(
  id: 'item-lemonade',
  sku: 'D-001',
  name: 'Лимонад',
  category: MenuItemCategoryRef(id: 'cat-drinks', name: 'Напитки'),
  price: Money.kopecks(15000),
  sortOrder: 0,
  isPopular: false,
  isNew: false,
  isHalal: true,
  available: true,
  modifierGroups: [],
);

final _submitButton = find.byKey(const ValueKey('checkout-submit-button'));
final _offerCheckbox = find.byKey(const ValueKey('offer-checkbox'));
final _addressField = find.byKey(const ValueKey('address-field'));

bool _submitEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_submitButton).onPressed != null;

/// Pumps the cart tab with real blocs and a zero-latency fake checkout.
Future<CustomerCartBloc> _pumpCart(
  WidgetTester tester, {
  CustomerOrdersRepository? ordersRepository,
  VoidCallback? onGoToMenu,
}) async {
  final cartBloc = CustomerCartBloc();
  final checkoutCubit = CheckoutCubit(
    repository:
        ordersRepository ??
        FakeCustomerOrdersRepository(latency: Duration.zero),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CustomerCartBloc>.value(value: cartBloc),
          BlocProvider<CheckoutCubit>.value(value: checkoutCubit),
          BlocProvider<OrderTypeCubit>(create: (_) => OrderTypeCubit()),
        ],
        child: Scaffold(body: CartScreen(onGoToMenu: onGoToMenu ?? () {})),
      ),
    ),
  );
  return cartBloc;
}

Future<void> _selectPickup(WidgetTester tester) async {
  final segment = find.text('Самовывоз (стойка)');
  await tester.ensureVisible(segment);
  await tester.tap(segment);
  await tester.pump();
}

Future<void> _acceptOffer(WidgetTester tester) async {
  await tester.ensureVisible(_offerCheckbox);
  await tester.tap(_offerCheckbox);
  await tester.pump();
}

void main() {
  testWidgets('пустая корзина: заглушка и кнопка перехода в меню', (
    tester,
  ) async {
    var navigated = false;
    await _pumpCart(tester, onGoToMenu: () => navigated = true);

    expect(find.text('Корзина пуста'), findsOneWidget);
    expect(_submitButton, findsNothing);

    await tester.tap(find.byKey(const ValueKey('go-to-menu-button')));
    expect(navigated, isTrue);
  });

  testWidgets('позиция с модификаторами: мелкий текст, + / − и удаление', (
    tester,
  ) async {
    final cart = await _pumpCart(tester);
    cart.add(
      CartItemAdded(
        item: _roll,
        selection: const {'mg-sauce': {'mi-s-spicy'}},
      ),
    );
    await tester.pump();

    // Название, модификаторы мелким текстом, цена и счётчик.
    expect(find.text('Филадельфия'), findsOneWidget);
    expect(find.text('Спайси'), findsOneWidget);
    expect(find.text('${const Money.kopecks(43000).format()} / шт'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(43000).format()}'),
      findsOneWidget,
    );

    const lineId = 'item-philadelphia|mi-s-spicy';

    // + увеличивает количество и итог.
    await tester.tap(find.byKey(const ValueKey('qty-plus-$lineId')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(86000).format()}'),
      findsOneWidget,
    );

    // − возвращает к одной штуке.
    await tester.tap(find.byKey(const ValueKey('qty-minus-$lineId')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // − при количестве 1 удаляет позицию.
    await tester.tap(find.byKey(const ValueKey('qty-minus-$lineId')));
    await tester.pump();
    expect(find.text('Корзина пуста'), findsOneWidget);
    expect(cart.state.isEmpty, isTrue);
  });

  testWidgets('удаление позиции кнопкой-корзиной', (tester) async {
    final cart = await _pumpCart(tester);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('remove-item-lemonade|')));
    await tester.pump();

    expect(find.text('Корзина пуста'), findsOneWidget);
    expect(cart.state.isEmpty, isTrue);
  });

  testWidgets('кнопка оформления заблокирована без чекбокса оферты', (
    tester,
  ) async {
    final cart = await _pumpCart(tester);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    // Самовывоз: адрес не нужен, но без оферты кнопка неактивна.
    await _selectPickup(tester);
    expect(_submitEnabled(tester), isFalse);

    await _acceptOffer(tester);
    expect(_submitEnabled(tester), isTrue);

    // Снятие чекбокса снова блокирует кнопку.
    await _acceptOffer(tester);
    expect(_submitEnabled(tester), isFalse);
  });

  testWidgets('при доставке кнопка требует заполненный адрес', (tester) async {
    final cart = await _pumpCart(tester);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    // По умолчанию выбрана доставка.
    await _acceptOffer(tester);
    expect(_submitEnabled(tester), isFalse);

    await tester.ensureVisible(_addressField);
    await tester.enterText(_addressField, 'ул. Пушкина, д. 10, кв. 5');
    await tester.pump();
    expect(_submitEnabled(tester), isTrue);

    // Поле адреса отключено при самовывозе.
    await _selectPickup(tester);
    expect(tester.widget<TextField>(_addressField).enabled, isFalse);
  });

  testWidgets('успешное оформление: экран поздравления, корзина очищена', (
    tester,
  ) async {
    var backToMenu = false;
    final cart = await _pumpCart(
      tester,
      onGoToMenu: () => backToMenu = true,
    );
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    await _selectPickup(tester);
    await _acceptOffer(tester);

    await tester.tap(_submitButton);
    await tester.pump();
    await tester.pump();

    // Экран поздравления с номером заказа и таймером ожидания.
    expect(find.text('Заказ #1042 принят!'), findsOneWidget);
    expect(find.text('Готовим для вас'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);

    // Таймер тикает.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('29:59'), findsOneWidget);

    // Корзина очищена после успешного чекаута.
    expect(cart.state.isEmpty, isTrue);

    // Возврат в меню: закрываем экран и дергаем колбэк оболочки.
    await tester.tap(find.byKey(const ValueKey('back-to-menu-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(backToMenu, isTrue);
    expect(find.text('Корзина пуста'), findsOneWidget);
  });
}
