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
import 'package:customer_mobile/features/cart/data/create_order_request.dart';
import 'package:customer_mobile/features/cart/data/guest_order.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/cart/view/cart_screen.dart';
import 'package:customer_mobile/features/loyalty/bloc/loyalty_cubit.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_repository.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/payments/data/fake_payments_repository.dart';
import 'package:customer_mobile/features/orders/data/order_tracking_repository.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_settings_repository.dart';

/// Ролл за 390,00 ₽: лимит списания 30% = 117 бонусов (ADR-1614).
const _roll = MenuItem(
  id: 'item-philadelphia',
  sku: 'R-001',
  name: 'Филадельфия',
  category: MenuItemCategoryRef(id: 'cat-rolls', name: 'Роллы'),
  price: Money.kopecks(39000),
  sortOrder: 0,
  isPopular: true,
  isNew: false,
  isHalal: true,
  available: true,
  modifierGroups: [],
);

final _bonusSection = find.byKey(const ValueKey('bonus-spend-section'));
final _bonusSwitch = find.byKey(const ValueKey('bonus-spend-switch'));
final _bonusDiscountRow = find.byKey(const ValueKey('bonus-discount-row'));
final _submitButton = find.byKey(const ValueKey('checkout-submit-button'));
final _offerCheckbox = find.byKey(const ValueKey('offer-checkbox'));

/// Захватывает последний запрос чекаута, чтобы проверить `useBonusPoints`.
final class _CapturingOrdersRepository implements CustomerOrdersRepository {
  CreateOrderRequest? lastRequest;

  @override
  Future<GuestOrder> createOrder(CreateOrderRequest request) async {
    lastRequest = request;
    return const GuestOrder(
      id: 'order-1',
      orderNumber: '1042',
      status: 'NEW',
      totalAmount: Money.zero,
    );
  }
}

Future<AuthBloc> _authenticatedAuthBloc() async {
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

AuthBloc _anonymousAuthBloc() => AuthBloc(
  repository: FakeAuthRepository(latency: Duration.zero),
  tokenStorage: InMemoryAuthTokenStorage(),
  tokenProvider: AuthTokenProvider(),
)..add(const AuthStarted());

/// Корзина с реальными блоками и уже загруженным балансом лояльности.
Future<CustomerCartBloc> _pumpCart(
  WidgetTester tester, {
  required AuthBloc authBloc,
  int balance = 500,
  double cashbackRate = 5,
  CustomerOrdersRepository? ordersRepository,
  LoyaltyCubit? loyaltyCubit,
}) async {
  // Высокий вьюпорт: весь ленивый ListView собран, секция списания видна.
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final cartBloc = CustomerCartBloc();
  final loyalty =
      loyaltyCubit ??
      LoyaltyCubit(
        repository: FakeLoyaltyRepository(
          latency: Duration.zero,
          balance: balance,
          cashbackRate: cashbackRate,
        ),
      );
  await loyalty.loadBalance();
  await tester.pumpWidget(
    BlocProvider<UserSettingsCubit>(
      create: (_) => UserSettingsCubit(FakeUserSettingsRepository()),
      child: MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<CustomerCartBloc>.value(value: cartBloc),
            BlocProvider<CheckoutCubit>(
              create: (_) => CheckoutCubit(
                repository: ordersRepository ?? _CapturingOrdersRepository(),
                paymentsRepository: FakeCustomerPaymentsRepository(
                  latency: Duration.zero,
                ),
              ),
            ),
            BlocProvider<OrderTypeCubit>(create: (_) => OrderTypeCubit()),
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<LoyaltyCubit>.value(value: loyalty),
          ],
          child: Scaffold(
            body: CartScreen(
              onGoToMenu: () {},
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
  cartBloc.add(const CartItemAdded(item: _roll));
  await tester.pump();
  return cartBloc;
}

Future<void> _enableBonusSpend(WidgetTester tester) async {
  await tester.ensureVisible(_bonusSwitch);
  await tester.tap(_bonusSwitch);
  await tester.pump();
}

void main() {
  testWidgets('авторизованный гость видит переключатель списания бонусов', (
    tester,
  ) async {
    await _pumpCart(tester, authBloc: await _authenticatedAuthBloc());

    expect(_bonusSection, findsOneWidget);
    expect(find.text('Списать бонусы'), findsOneWidget);
    expect(
      find.text('На балансе 500 бонусов · спишется 117 (до 30% от чека)'),
      findsOneWidget,
    );
    // Пока переключатель выключен — скидки нет, итог полный.
    expect(_bonusDiscountRow, findsNothing);
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(39000).format()}'),
      findsOneWidget,
    );
  });

  testWidgets('включение списания пересчитывает итог с лимитом 30% от чека', (
    tester,
  ) async {
    await _pumpCart(tester, authBloc: await _authenticatedAuthBloc());
    await _enableBonusSpend(tester);

    // 30% от 390,00 ₽ = 117 бонусов; итог 390,00 − 117,00 = 273,00 ₽.
    expect(_bonusDiscountRow, findsOneWidget);
    expect(
      find.text('−${const Money.kopecks(11700).format()}'),
      findsOneWidget,
    );
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(27300).format()}'),
      findsOneWidget,
    );

    // Повторный тап возвращает исходный итог.
    await _enableBonusSpend(tester);
    expect(_bonusDiscountRow, findsNothing);
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(39000).format()}'),
      findsOneWidget,
    );
  });

  testWidgets('баланс меньше лимита: списывается весь баланс', (tester) async {
    await _pumpCart(
      tester,
      authBloc: await _authenticatedAuthBloc(),
      balance: 100,
    );
    await _enableBonusSpend(tester);

    expect(
      find.text('−${const Money.kopecks(10000).format()}'),
      findsOneWidget,
    );
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(29000).format()}'),
      findsOneWidget,
    );
  });

  testWidgets('динамический пересчёт при изменении количества позиций', (
    tester,
  ) async {
    await _pumpCart(tester, authBloc: await _authenticatedAuthBloc());
    await _enableBonusSpend(tester);
    expect(
      find.text('−${const Money.kopecks(11700).format()}'),
      findsOneWidget,
    );

    // +1 ролл: чек 780,00 ₽ → лимит 234 бонуса → итог 546,00 ₽.
    await tester.ensureVisible(
      find.byKey(const ValueKey('qty-plus-item-philadelphia|')),
    );
    await tester.tap(find.byKey(const ValueKey('qty-plus-item-philadelphia|')));
    await tester.pump();

    expect(
      find.text('−${const Money.kopecks(23400).format()}'),
      findsOneWidget,
    );
    expect(
      find.text('Оформить заказ на ${const Money.kopecks(54600).format()}'),
      findsOneWidget,
    );
  });

  testWidgets('чекаут отправляет useBonusPoints по контракту ADR-1614', (
    tester,
  ) async {
    final orders = _CapturingOrdersRepository();
    await _pumpCart(
      tester,
      authBloc: await _authenticatedAuthBloc(),
      ordersRepository: orders,
    );
    await _enableBonusSpend(tester);

    // Самовывоз + оферта: кнопка активна.
    await tester.ensureVisible(find.text('Самовывоз (стойка)'));
    await tester.tap(find.text('Самовывоз (стойка)'));
    await tester.pump();
    await tester.ensureVisible(_offerCheckbox);
    await tester.tap(_offerCheckbox);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('payment-method-onDelivery')));
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pump();
    await tester.pump();

    final request = orders.lastRequest;
    expect(request, isNotNull);
    expect(request!.useBonusPoints, 117);
    expect(request.toJson()['useBonusPoints'], 117);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
  });

  testWidgets('без списания поле useBonusPoints не уходит в чекаут', (
    tester,
  ) async {
    final orders = _CapturingOrdersRepository();
    await _pumpCart(
      tester,
      authBloc: await _authenticatedAuthBloc(),
      ordersRepository: orders,
    );

    await tester.ensureVisible(find.text('Самовывоз (стойка)'));
    await tester.tap(find.text('Самовывоз (стойка)'));
    await tester.pump();
    await tester.ensureVisible(_offerCheckbox);
    await tester.tap(_offerCheckbox);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('payment-method-onDelivery')));
    await tester.pump();
    await tester.tap(_submitButton);
    await tester.pump();
    await tester.pump();

    expect(orders.lastRequest, isNotNull);
    expect(orders.lastRequest!.useBonusPoints, 0);
    expect(orders.lastRequest!.toJson().containsKey('useBonusPoints'), isFalse);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
  });

  testWidgets('анонимный гость не видит секцию списания', (tester) async {
    await _pumpCart(tester, authBloc: _anonymousAuthBloc());

    expect(_bonusSection, findsNothing);
    expect(find.text('Списать бонусы'), findsNothing);
  });

  testWidgets('нулевой баланс: секция скрыта', (tester) async {
    await _pumpCart(
      tester,
      authBloc: await _authenticatedAuthBloc(),
      balance: 0,
    );

    expect(_bonusSection, findsNothing);
  });
}
