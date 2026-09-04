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
import 'package:customer_mobile/features/cart/view/cart_screen.dart';
import 'package:customer_mobile/features/legal/data/legal_constants.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/payments/data/fake_payments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

final _footnote = find.byKey(const ValueKey('checkout-legal-footnote'));
final _sheetClose = find.byKey(const ValueKey('legal-sheet-close'));

/// Корзина с одной позицией и анонимной сессией: сноска согласия
/// видна в панели оформления без скролла.
Future<void> _pumpCart(WidgetTester tester) async {
  final cartBloc = CustomerCartBloc();
  addTearDown(cartBloc.close);
  final checkoutCubit = CheckoutCubit(
    repository: FakeCustomerOrdersRepository(latency: Duration.zero),
    paymentsRepository: FakeCustomerPaymentsRepository(latency: Duration.zero),
  );
  addTearDown(checkoutCubit.close);
  final authBloc = AuthBloc(
    repository: FakeAuthRepository(latency: Duration.zero),
    tokenStorage: InMemoryAuthTokenStorage(),
    tokenProvider: AuthTokenProvider(),
  )..add(const AuthStarted());
  addTearDown(authBloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CustomerCartBloc>.value(value: cartBloc),
          BlocProvider<CheckoutCubit>.value(value: checkoutCubit),
          BlocProvider<OrderTypeCubit>(create: (_) => OrderTypeCubit()),
          BlocProvider<AuthBloc>.value(value: authBloc),
        ],
        child: Scaffold(body: CartScreen(onGoToMenu: () {})),
      ),
    ),
  );
  cartBloc.add(const CartItemAdded(item: _drink));
  await tester.pump();
}

void main() {
  testWidgets('сноска согласия отображается перед кнопкой оформления', (
    tester,
  ) async {
    await _pumpCart(tester);

    expect(_footnote, findsOneWidget);
    expect(
      find.textRange.ofSubstring(
        'Нажимая кнопку оплаты, вы соглашаетесь с условиями ',
      ),
      findsOneWidget,
    );
    expect(find.textRange.ofSubstring('Оферты'), findsOneWidget);
    expect(
      find.textRange.ofSubstring('Политикой конфиденциальности'),
      findsOneWidget,
    );
  });

  testWidgets('ссылка «Оферты» открывает модальное окно с полным текстом', (
    tester,
  ) async {
    await _pumpCart(tester);

    await tester.tapOnText(find.textRange.ofSubstring('Оферты'));
    await tester.pumpAndSettle();

    // Модальное окно с полным текстом оферты поверх корзины.
    expect(_sheetClose, findsOneWidget);
    expect(find.text('Публичная оферта'), findsOneWidget);
    expect(
      find.textContaining('ИНН ${LegalConstants.operatorInn}'),
      findsOneWidget,
    );

    // Закрытие возвращает в корзину, позиция на месте.
    await tester.tap(_sheetClose);
    await tester.pumpAndSettle();
    expect(_sheetClose, findsNothing);
    expect(find.text('Лимонад'), findsOneWidget);
  });

  testWidgets(
    'ссылка «Политикой конфиденциальности» открывает политику модально',
    (tester) async {
      await _pumpCart(tester);

      await tester.tapOnText(
        find.textRange.ofSubstring('Политикой конфиденциальности'),
      );
      await tester.pumpAndSettle();

      expect(_sheetClose, findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(find.textContaining('152-ФЗ'), findsWidgets);

      // Длинный текст скроллится до раздела о локализации данных.
      await tester.scrollUntilVisible(
        find.textContaining('Таймвэб.Облако'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('Таймвэб.Облако'), findsOneWidget);

      await tester.tap(_sheetClose);
      await tester.pumpAndSettle();
      expect(_sheetClose, findsNothing);
      expect(_footnote, findsOneWidget);
    },
  );
}
