import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/config/pos_context_cubit.dart';
import 'package:pos/core/utils/money.dart';
import 'package:pos/features/cart/bloc/cart_bloc.dart';
import 'package:pos/features/cart/bloc/cart_event.dart';
import 'package:pos/features/cart/bloc/cart_state.dart';
import 'package:pos/features/cart/domain/cart_line.dart';
import 'package:pos/features/cart/view/cart_panel.dart';
import 'package:pos/features/orders/data/create_order_request.dart';
import 'package:pos/features/orders/data/fake_orders_repository.dart';
import 'package:pos/features/orders/data/orders_repository.dart';
import 'package:pos/features/orders/domain/order_entity.dart';
import 'package:pos/features/tables/bloc/order_mode_cubit.dart';

import '../../../helpers/test_fixtures.dart';

final class _FailingOrdersRepository implements OrdersRepository {
  @override
  Future<OrderEntity> createOrder(CreateOrderRequest request) =>
      throw const OrdersException('Сервер недоступен');
}

void main() {
  Widget wrap(CartBloc cartBloc) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CartBloc>.value(value: cartBloc),
        BlocProvider(create: (_) => OrderModeCubit()),
        BlocProvider(create: (_) => PosContextCubit()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, child: CartPanel())),
      ),
    );
  }

  CartBloc cartBloc({OrdersRepository? repository}) => CartBloc(
    ordersRepository:
        repository ?? FakeOrdersRepository(latency: Duration.zero),
  );

  group('CartPanel', () {
    testWidgets('shows the empty state when the cart has no lines', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(cartBloc()));

      expect(find.text('Корзина пуста'), findsOneWidget);
      expect(find.text('Текущий заказ'), findsOneWidget);

      final checkout = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('К оплате'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(checkout.onPressed, isNull);
    });

    testWidgets('renders lines with modifiers and the RUB total', (
      tester,
    ) async {
      final cart = cartBloc()
        ..add(
          CartItemAdded(
            item: testMenuItem(),
            modifiers: const [
              SelectedModifier(
                groupId: 'mg-sauce',
                groupName: 'Соус',
                optionId: 'mi-spicy',
                optionName: 'Спайси',
                price: Money.kopecks(4000),
              ),
            ],
          ),
        );
      await tester.pumpWidget(wrap(cart));
      await tester.pump();

      expect(find.text('Филадельфия'), findsOneWidget);
      expect(find.text('Спайси'), findsOneWidget);
      // 390,00 + 40,00 = 430,00 ₽ shown as both line total and grand total.
      expect(find.textContaining('430,00'), findsNWidgets(2));
    });

    testWidgets('steppers change quantity and remove at zero', (tester) async {
      final cart = cartBloc()..add(CartItemAdded(item: testMenuItem()));
      await tester.pumpWidget(wrap(cart));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(cart.state.lines.single.quantity, 2);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(cart.state.isEmpty, isTrue);
      expect(find.text('Корзина пуста'), findsOneWidget);
    });

    testWidgets('clear button empties the cart', (tester) async {
      final cart = cartBloc()..add(CartItemAdded(item: testMenuItem()));
      await tester.pumpWidget(wrap(cart));
      await tester.pump();

      await tester.tap(find.text('Очистить'));
      await tester.pump();
      expect(cart.state.isEmpty, isTrue);
    });
  });

  group('CartPanel checkout', () {
    testWidgets(
      'sends the order, confirms with the order number and clears the cart',
      (tester) async {
        final cart = cartBloc()..add(CartItemAdded(item: testMenuItem()));
        await tester.pumpWidget(wrap(cart));
        await tester.pump();

        await tester.tap(find.text('К оплате'));
        await tester.pumpAndSettle();

        // Confirmation dialog with the large order number.
        expect(find.text('Заказ #1005'), findsOneWidget);
        expect(
          find.text('Заказ #1005 успешно отправлен на кухню!'),
          findsOneWidget,
        );
        expect(cart.state.checkoutStatus, CheckoutStatus.success);
        expect(cart.state.isEmpty, isTrue);

        await tester.tap(find.text('Новый заказ'));
        await tester.pumpAndSettle();

        // Dialog closed, cart is empty and ready for the next order.
        expect(find.text('Заказ #1005'), findsNothing);
        expect(find.text('Корзина пуста'), findsOneWidget);
        expect(cart.state.checkoutStatus, CheckoutStatus.idle);
      },
    );

    testWidgets('blocks the button and shows a spinner while submitting', (
      tester,
    ) async {
      final cart = cartBloc(
        repository: FakeOrdersRepository(
          latency: const Duration(milliseconds: 500),
        ),
      )..add(CartItemAdded(item: testMenuItem()));
      await tester.pumpWidget(wrap(cart));
      await tester.pump();

      await tester.tap(find.text('К оплате'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Отправка…'),
      );
      expect(button.onPressed, isNull);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Заказ #1005'), findsOneWidget);
    });

    testWidgets('failure shows a snackbar and keeps the cart', (tester) async {
      final cart = cartBloc(repository: _FailingOrdersRepository())
        ..add(CartItemAdded(item: testMenuItem()));
      await tester.pumpWidget(wrap(cart));
      await tester.pump();

      await tester.tap(find.text('К оплате'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Сервер недоступен'), findsOneWidget);
      expect(find.text('Филадельфия'), findsOneWidget);
      expect(cart.state.lines, hasLength(1));
      expect(cart.state.checkoutStatus, CheckoutStatus.idle);

      // Let the snackbar auto-dismiss so no timers leak past the test.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
