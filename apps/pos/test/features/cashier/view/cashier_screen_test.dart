import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/app/app.dart';
import 'package:pos/features/catalog/data/fake_catalog_repository.dart';
import 'package:pos/features/orders/data/fake_orders_repository.dart';

void main() {
  Future<void> pumpCashier(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PosApp(
        catalogRepository: FakeCatalogRepository(latency: Duration.zero),
        ordersRepository: FakeOrdersRepository(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CashierScreen (desktop 1440×900)', () {
    testWidgets('renders context selectors, categories, cards and cart', (
      tester,
    ) async {
      await pumpCashier(tester);

      // Context bar ("В зале" appears in both the mode switch and the
      // cart header chip).
      expect(find.text('SHIK ROLL'), findsOneWidget);
      expect(find.text('Центральный'), findsOneWidget);
      expect(find.text('В зале'), findsWidgets);
      expect(find.text('Навынос'), findsOneWidget);

      // Category rail.
      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Роллы'), findsWidgets);
      expect(find.text('Напитки'), findsOneWidget);

      // Product grid (first page of the demo catalog).
      expect(find.text('Филадельфия'), findsOneWidget);
      expect(find.text('Калифорния'), findsOneWidget);

      // Cart panel starts empty.
      expect(find.text('Корзина пуста'), findsOneWidget);
      expect(find.text('Текущий заказ'), findsOneWidget);
    });

    testWidgets('halal filter keeps only halal items', (tester) async {
      await pumpCashier(tester);

      await tester.tap(find.text('Халяль'));
      await tester.pumpAndSettle();

      expect(find.text('Филадельфия'), findsNothing);
      expect(find.text('Калифорния'), findsOneWidget);
      expect(find.text('Овощной ролл'), findsOneWidget);
    });

    testWidgets('category rail filters the product grid', (tester) async {
      await pumpCashier(tester);

      await tester.tap(find.text('Напитки'));
      await tester.pumpAndSettle();

      expect(find.text('Морс клюквенный'), findsOneWidget);
      expect(find.text('Чай зелёный'), findsOneWidget);
      expect(find.text('Филадельфия'), findsNothing);
    });

    testWidgets('tapping an item without modifiers adds it to the cart', (
      tester,
    ) async {
      await pumpCashier(tester);

      await tester.tap(find.text('Напитки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Морс клюквенный'));
      await tester.pumpAndSettle();

      // Cart shows the line and the exact RUB total (90,00 ₽).
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Морс клюквенный'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('90,00'), findsWidgets);
      expect(find.text('Корзина пуста'), findsNothing);
    });

    testWidgets('modifier sheet enforces required groups before adding', (
      tester,
    ) async {
      await pumpCashier(tester);

      await tester.tap(find.text('Роллы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Филадельфия'));
      await tester.pumpAndSettle();

      // Sheet is open; required portion group is not selected yet.
      expect(find.text('Порция'), findsOneWidget);
      expect(find.text('обязательно'), findsWidgets);
      final addButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Добавить в заказ'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(addButton.onPressed, isNull);

      // Choose the required portion and an optional sauce.
      await tester.tap(find.text('Большая'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Спайси'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Добавить в заказ'));
      await tester.pumpAndSettle();

      // Cart line: 390,00 + 150,00 (portion) + 40,00 (sauce) = 580,00 ₽.
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Филадельфия'),
        ),
        findsOneWidget,
      );
      expect(find.text('Большая, Спайси'), findsOneWidget);
      expect(find.textContaining('580,00'), findsWidgets);
    });

    testWidgets('switching to takeaway updates the cart header', (
      tester,
    ) async {
      await pumpCashier(tester);

      await tester.tap(find.text('Навынос'));
      await tester.pumpAndSettle();

      // The cart header chip reflects the mode.
      final chip = find.descendant(
        of: find.byType(Chip),
        matching: find.text('Навынос'),
      );
      expect(chip, findsOneWidget);
    });
  });
}
