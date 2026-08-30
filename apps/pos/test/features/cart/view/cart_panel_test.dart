import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/utils/money.dart';
import 'package:pos/features/cart/bloc/cart_bloc.dart';
import 'package:pos/features/cart/bloc/cart_event.dart';
import 'package:pos/features/cart/domain/cart_line.dart';
import 'package:pos/features/cart/view/cart_panel.dart';
import 'package:pos/features/tables/bloc/order_mode_cubit.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Widget wrap(CartBloc cartBloc, {VoidCallback? onCheckout}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CartBloc>.value(value: cartBloc),
        BlocProvider(create: (_) => OrderModeCubit()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, child: CartPanel(onCheckout: onCheckout)),
        ),
      ),
    );
  }

  group('CartPanel', () {
    testWidgets('shows the empty state when the cart has no lines', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(CartBloc()));

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
      final cart = CartBloc()
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
      final cart = CartBloc()..add(CartItemAdded(item: testMenuItem()));
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

    testWidgets('checkout button is enabled with items and fires callback', (
      tester,
    ) async {
      var checkouts = 0;
      final cart = CartBloc()..add(CartItemAdded(item: testMenuItem()));
      await tester.pumpWidget(wrap(cart, onCheckout: () => checkouts++));
      await tester.pump();

      await tester.tap(find.text('К оплате'));
      await tester.pump();
      expect(checkouts, 1);
    });

    testWidgets('clear button empties the cart', (tester) async {
      final cart = CartBloc()..add(CartItemAdded(item: testMenuItem()));
      await tester.pumpWidget(wrap(cart));
      await tester.pump();

      await tester.tap(find.text('Очистить'));
      await tester.pump();
      expect(cart.state.isEmpty, isTrue);
    });
  });
}
