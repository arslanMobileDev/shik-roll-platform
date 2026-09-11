import 'package:customer_mobile/core/auth/auth_session.dart';
import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/cart/bloc/cart_event.dart';
import 'package:customer_mobile/features/cart/bloc/checkout_cubit.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/cart/data/fake_orders_repository.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/cart/view/cart_screen.dart';
import 'package:customer_mobile/features/loyalty/bloc/loyalty_cubit.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_repository.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/payments/data/fake_payments_repository.dart';
import 'package:customer_mobile/features/payments/data/payments_repository.dart';
import 'package:customer_mobile/features/orders/data/order_tracking_repository.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_settings_repository.dart';

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
final _streetField = find.byKey(const ValueKey('street-field'));
final _houseField = find.byKey(const ValueKey('house-field'));
final _timeToggle = find.byKey(const ValueKey('delivery-time-toggle'));

bool _submitEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_submitButton).onPressed != null;

/// AuthBloc with a persisted session restored: the guest is authenticated.
Future<AuthBloc> _loggedInAuthBloc() async {
  final storage = InMemoryAuthTokenStorage();
  await storage.save(
    const StoredAuthSession(
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      customerId: 'customer-1',
      phone: '+79991234567',
      name: 'Тест',
    ),
  );
  final bloc = AuthBloc(
    repository: FakeAuthRepository(latency: Duration.zero),
    tokenStorage: storage,
    tokenProvider: AuthTokenProvider(),
  )..add(const AuthStarted());
  await bloc.stream.firstWhere((s) => s.isAuthenticated);
  return bloc;
}

/// AuthBloc without a session: the guest is anonymous.
AuthBloc _anonymousAuthBloc() {
  final bloc = AuthBloc(
    repository: FakeAuthRepository(latency: Duration.zero),
    tokenStorage: InMemoryAuthTokenStorage(),
    tokenProvider: AuthTokenProvider(),
  )..add(const AuthStarted());
  return bloc;
}

/// Pumps the cart tab with real blocs and a zero-latency fake checkout.
Future<CustomerCartBloc> _pumpCart(
  WidgetTester tester, {
  CustomerOrdersRepository? ordersRepository,
  CustomerPaymentsRepository? paymentsRepository,
  VoidCallback? onGoToMenu,
  AuthBloc? authBloc,
}) async {
  // Экран чекаута длинный, а ListView ленивый: даём тестовому surface
  // достаточную высоту, чтобы все дети (адрес, время, оферта, оплата)
  // были построены и доступны finder'ам без скроллинга.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final cartBloc = CustomerCartBloc();
  final checkoutCubit = CheckoutCubit(
    repository:
        ordersRepository ??
        FakeCustomerOrdersRepository(latency: Duration.zero),
    paymentsRepository:
        paymentsRepository ??
        FakeCustomerPaymentsRepository(latency: Duration.zero),
  );
  final auth = authBloc ?? await _loggedInAuthBloc();
  await tester.pumpWidget(
    BlocProvider<UserSettingsCubit>(
      create: (_) => UserSettingsCubit(FakeUserSettingsRepository()),
      child: MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<CustomerCartBloc>.value(value: cartBloc),
            BlocProvider<CheckoutCubit>.value(value: checkoutCubit),
            BlocProvider<OrderTypeCubit>(create: (_) => OrderTypeCubit()),
            BlocProvider<AuthBloc>.value(value: auth),
            // Без загруженного баланса секция списания бонусов скрыта —
            // сценарии этого файла лояльность не задействуют.
            BlocProvider<LoyaltyCubit>(
              create: (_) => LoyaltyCubit(
                repository: FakeLoyaltyRepository(
                  latency: Duration.zero,
                  balance: 0,
                ),
              ),
            ),
          ],
          child: Scaffold(
            body: CartScreen(
              onGoToMenu: onGoToMenu ?? () {},
            orderTrackingRepository: FakeOrderTrackingRepository(
              latency: Duration.zero,
              script: const ['NEW'],
            ),
            ),
          ),
        ),
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
        selection: const {
          'mg-sauce': {'mi-s-spicy'},
        },
      ),
    );
    await tester.pump();

    // Название, модификаторы мелким текстом, цена и счётчик.
    expect(find.text('Филадельфия'), findsOneWidget);
    expect(find.text('Спайси'), findsOneWidget);
    expect(
      find.text('${const Money.kopecks(43000).format()} / шт'),
      findsOneWidget,
    );
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

  testWidgets('при доставке кнопка требует улицу и дом', (tester) async {
    final cart = await _pumpCart(tester);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    // По умолчанию выбрана доставка.
    await _acceptOffer(tester);
    expect(_submitEnabled(tester), isFalse);

    // Одной улицы недостаточно.
    await tester.ensureVisible(_streetField);
    await tester.enterText(_streetField, 'ул. Пушкина');
    await tester.pump();
    expect(_submitEnabled(tester), isFalse);

    await tester.ensureVisible(_houseField);
    await tester.enterText(_houseField, '10');
    await tester.pump();
    expect(_submitEnabled(tester), isTrue);

    // При самовывозе форма адреса скрыта, адрес не требуется.
    await _selectPickup(tester);
    expect(_streetField, findsNothing);
    expect(_houseField, findsNothing);
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('блок сумм: товары, доставка и итог', (tester) async {
    final cart = await _pumpCart(tester);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    expect(find.text('Сумма заказа'), findsOneWidget);
    // Текст «Доставка» совпадает с сегментом OrderTypeToggle — строку сумм
    // ищем по ключу.
    final feeRow = find.byKey(const ValueKey('delivery-fee-row'));
    expect(feeRow, findsOneWidget);
    // deliveryFee по умолчанию 0 — доставка бесплатна.
    expect(
      find.descendant(of: feeRow, matching: find.text('Бесплатно')),
      findsOneWidget,
    );
    expect(find.text('Итого'), findsOneWidget);
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(15000).format()}'),
      findsOneWidget,
    );
  });

  testWidgets('время получения: ASAP по умолчанию, «Ко времени» ловит слот', (
    tester,
  ) async {
    final cart = await _pumpCart(tester);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    // ASAP: кнопки выбранного времени нет.
    expect(find.byKey(const ValueKey('scheduled-time-button')), findsNothing);

    await tester.ensureVisible(_timeToggle);
    await tester.tap(find.text('Ко времени'));
    await tester.pumpAndSettle();

    // Диалог выбора времени открыт; подтверждаем слот по умолчанию.
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Слот зафиксирован: видна кнопка с выбранным временем.
    expect(find.byKey(const ValueKey('scheduled-time-button')), findsOneWidget);

    // Возврат к ASAP сбрасывает слот.
    await tester.tap(find.text('Как можно скорее'));
    await tester.pump();
    expect(find.byKey(const ValueKey('scheduled-time-button')), findsNothing);
  });

  testWidgets('успешное оформление: экран трекинга, корзина очищена', (
    tester,
  ) async {
    final cart = await _pumpCart(tester);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    await _selectPickup(tester);
    await _acceptOffer(tester);
    await tester.tap(find.byKey(const ValueKey('payment-method-onDelivery')));
    await tester.pump();

    await tester.tap(_submitButton);
    await tester.pump();
    await tester.pump();

    expect(find.text('Отслеживание заказа'), findsOneWidget);

    // Корзина очищена после успешного чекаута.
    expect(cart.state.isEmpty, isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    expect(find.text('Корзина пуста'), findsOneWidget);
  });

  testWidgets('гость не авторизован: модальный вход по SMS без сброса корзины, '
      'затем заказ уходит', (tester) async {
    final auth = _anonymousAuthBloc();
    final cart = await _pumpCart(tester, authBloc: auth);
    cart.add(const CartItemAdded(item: _drink));
    await tester.pump();

    await _selectPickup(tester);
    await _acceptOffer(tester);
    await tester.tap(find.byKey(const ValueKey('payment-method-onDelivery')));
    await tester.pump();

    // Тап по «Оформить заказ» открывает модальный вход, заказ не уходит.
    await tester.tap(_submitButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-field')), findsOneWidget);
    expect(cart.state.isEmpty, isFalse);

    // Вводим номер и запрашиваем код.
    await tester.enterText(
      find.byKey(const ValueKey('phone-field')),
      '9991234567',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-code-button')));
    // Bounded pumps: дальше работает таймер повторной отправки.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('otp-field')), findsOneWidget);

    // Вводим код: вход завершается, шторка закрывается, заказ уходит.
    await tester.enterText(find.byKey(const ValueKey('otp-field')), '1234');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Отслеживание заказа'), findsOneWidget);
    expect(cart.state.isEmpty, isTrue);
    expect(auth.state.isAuthenticated, isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
  });
}
