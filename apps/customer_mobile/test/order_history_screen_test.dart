import 'package:customer_mobile/core/auth/auth_session.dart';
import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/menu/bloc/menu_bloc.dart';
import 'package:customer_mobile/features/menu/bloc/menu_event.dart';
import 'package:customer_mobile/features/menu/bloc/menu_state.dart';
import 'package:customer_mobile/features/menu/data/fake_customer_menu_repository.dart';
import 'package:customer_mobile/features/orders/bloc/order_history_bloc.dart';
import 'package:customer_mobile/features/orders/data/order_history_models.dart';
import 'package:customer_mobile/features/orders/data/order_history_repository.dart';
import 'package:customer_mobile/features/orders/view/order_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Always-failing history for the error-state test.
final class _FailingOrderHistoryRepository implements OrderHistoryRepository {
  @override
  Future<List<OrderHistoryEntry>> getOrders() => throw const OrdersException(
    'Сервер не отвечает. Проверьте интернет и повторите попытку.',
  );
}

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

AuthBloc _anonymousAuthBloc() => AuthBloc(
  repository: FakeAuthRepository(latency: Duration.zero),
  tokenStorage: InMemoryAuthTokenStorage(),
  tokenProvider: AuthTokenProvider(),
)..add(const AuthStarted());

Future<MenuBloc> _loadedMenuBloc() async {
  final bloc = MenuBloc(
    repository: FakeCustomerMenuRepository(latency: Duration.zero),
  )..add(MenuStarted());
  await bloc.stream.firstWhere((s) => s.status == MenuStatus.loaded);
  return bloc;
}

Future<CustomerCartBloc> _pumpOrders(
  WidgetTester tester, {
  required AuthBloc authBloc,
  OrderHistoryRepository? historyRepository,
  MenuBloc? menuBloc,
  VoidCallback? onGoToCart,
}) async {
  final cartBloc = CustomerCartBloc();
  final historyBloc = OrderHistoryBloc(
    repository:
        historyRepository ?? FakeOrderHistoryRepository(latency: Duration.zero),
  );
  final menu =
      menuBloc ??
      MenuBloc(repository: FakeCustomerMenuRepository(latency: Duration.zero))
        ..add(MenuStarted());
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<OrderHistoryBloc>.value(value: historyBloc),
          BlocProvider<CustomerCartBloc>.value(value: cartBloc),
          BlocProvider<MenuBloc>.value(value: menu),
        ],
        child: Scaffold(
          body: OrderHistoryScreen(onGoToCart: onGoToCart ?? () {}),
        ),
      ),
    ),
  );
  return cartBloc;
}

void main() {
  testWidgets('гость не авторизован: приглашение войти вместо списка', (
    tester,
  ) async {
    await _pumpOrders(tester, authBloc: _anonymousAuthBloc());
    await tester.pump();
    await tester.pump();

    expect(find.text('Войдите, чтобы увидеть заказы'), findsOneWidget);
    expect(find.byKey(const ValueKey('orders-login-button')), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('список заказов: дата, состав, сумма и бейджи статусов', (
    tester,
  ) async {
    final authBloc = await _loggedInAuthBloc();
    await _pumpOrders(tester, authBloc: authBloc);
    await tester.pump();
    await tester.pump();

    // Заказ #1042 в работе, #1035 доставлен.
    expect(find.text('Заказ #1042'), findsOneWidget);
    expect(find.text('Заказ #1035'), findsOneWidget);
    expect(find.text('Готовится'), findsOneWidget);
    expect(find.text('Доставлен'), findsOneWidget);

    // Дата и состав.
    expect(find.text('04.09.2026, 12:30'), findsOneWidget);
    expect(find.text('Филадельфия'), findsOneWidget);
    expect(find.text('Спайси'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);

    // Суммы в рублях.
    expect(find.text(const Money.kopecks(78000).format()), findsOneWidget);
    expect(find.text(const Money.kopecks(54000).format()), findsOneWidget);
  });

  testWidgets('«Повторить заказ» добавляет позиции в корзину', (tester) async {
    var wentToCart = false;
    final authBloc = await _loggedInAuthBloc();
    final menuBloc = await _loadedMenuBloc();
    final cart = await _pumpOrders(
      tester,
      authBloc: authBloc,
      menuBloc: menuBloc,
      onGoToCart: () => wentToCart = true,
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('repeat-order-demo-order-1042')));
    await tester.pump();

    // Филадельфия ×2 с соусом «Спайси» вернулась в корзину одной строкой.
    expect(cart.state.lines, hasLength(1));
    final line = cart.state.lines.single;
    expect(line.item.id, 'item-philadelphia');
    expect(line.quantity, 2);
    expect(line.modifiers.single.id, 'mi-s-spicy');

    // Снэкбар с переходом в корзину.
    expect(find.text('Заказ добавлен в корзину'), findsOneWidget);
    // Даём анимации появления снэкбара завершиться, иначе tap промахивается.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('В корзину'));
    await tester.pump();
    expect(wentToCart, isTrue);
  });

  testWidgets('позиция вне меню: заказ не добавляется, есть пояснение', (
    tester,
  ) async {
    final authBloc = await _loggedInAuthBloc();
    final menuBloc = await _loadedMenuBloc();
    final orphan = OrderHistoryEntry(
      id: 'order-orphan',
      orderNumber: '9999',
      status: 'COMPLETED',
      type: 'DELIVERY',
      totalAmount: const Money.kopecks(10000),
      createdAt: DateTime(2026, 8, 20, 10, 0),
      items: const [
        OrderHistoryItem(
          menuItemId: 'item-removed-from-menu',
          name: 'Архивный ролл',
          quantity: 1,
          unitPrice: Money.kopecks(10000),
          modifiers: [],
        ),
      ],
    );
    final cart = await _pumpOrders(
      tester,
      authBloc: authBloc,
      menuBloc: menuBloc,
      historyRepository: FakeOrderHistoryRepository(
        latency: Duration.zero,
        orders: [orphan],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('repeat-order-order-orphan')));
    await tester.pump();

    expect(cart.state.isEmpty, isTrue);
    expect(
      find.text('Блюда из этого заказа сейчас недоступны'),
      findsOneWidget,
    );
  });

  testWidgets('ошибка загрузки: сообщение и кнопка повтора', (tester) async {
    final authBloc = await _loggedInAuthBloc();
    await _pumpOrders(
      tester,
      authBloc: authBloc,
      historyRepository: _FailingOrderHistoryRepository(),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Сервер не отвечает. Проверьте интернет и повторите попытку.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('orders-retry-button')), findsOneWidget);
  });

  testWidgets('пустая история: заглушка', (tester) async {
    final authBloc = await _loggedInAuthBloc();
    await _pumpOrders(
      tester,
      authBloc: authBloc,
      historyRepository: FakeOrderHistoryRepository(
        latency: Duration.zero,
        orders: const [],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Заказов пока нет'), findsOneWidget);
  });
}
