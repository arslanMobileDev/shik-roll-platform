import 'package:courier_mobile/data/repositories/courier_repository.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/orders/view/courier_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fakes.dart';

Widget buildScreen(CourierRepository repository) {
  return RepositoryProvider<CourierRepository>.value(
    value: repository,
    child: MaterialApp(home: CourierOrdersScreen(session: testSession)),
  );
}

void main() {
  testWidgets(
    'pickup tab shows READY and COOKING orders with address and comment',
    (tester) async {
      await tester.pumpWidget(buildScreen(FakeCourierRepository()));
      await tester.pumpAndSettle();

      // READY and COOKING orders of branch-center are visible.
      expect(find.text('#A-1024'), findsOneWidget);
      expect(find.text('#A-1025'), findsOneWidget);
      expect(find.text('ул. Баумана, 58'), findsOneWidget);
      expect(
        find.text('кв. 12 · под. 3 · эт. 5 · домофон 127'),
        findsOneWidget,
      );
      expect(find.text('Позвонить за 5 минут, спит ребенок'), findsOneWidget);
      expect(find.text('1 250 ₽'), findsOneWidget);
      expect(find.text('Требуется расчет'), findsOneWidget);
      expect(find.text('Оплачено онлайн'), findsOneWidget);
      expect(find.text('12:05'), findsOneWidget);

      // READY order can be taken; COOKING one is still on the kitchen.
      expect(find.text('Взять заказ'), findsOneWidget);
      expect(find.text('Ещё готовится'), findsOneWidget);
    },
  );

  testWidgets('switching to «Мои в пути» tab shows ON_WAY order', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мои в пути (1)'));
    await tester.pumpAndSettle();

    expect(find.text('#A-1027'), findsOneWidget);
    expect(find.text('#A-1024'), findsNothing);
    expect(find.text('Заказ доставлен'), findsOneWidget);
  });

  testWidgets('«Взять заказ» moves order from pickup tab to mine', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pickup_order-1001')));
    await tester.pumpAndSettle();

    // Pickup tab now has one order; badge counts updated.
    expect(find.text('Доступные (1)'), findsOneWidget);
    expect(find.text('Мои в пути (2)'), findsOneWidget);

    await tester.tap(find.text('Мои в пути (2)'));
    await tester.pumpAndSettle();
    expect(find.text('#A-1024'), findsOneWidget);
  });

  testWidgets(
    '«Заказ доставлен» requires confirmation and completes the order',
    (tester) async {
      await tester.pumpWidget(buildScreen(FakeCourierRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Мои в пути (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('complete_order-1004')));
      await tester.pumpAndSettle();

      // Confirmation dialog shown; cancel keeps the order.
      expect(find.text('Заказ #A-1027 доставлен?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.text('#A-1027'), findsOneWidget);

      // Confirm removes the order from the active list.
      await tester.tap(find.byKey(const Key('complete_order-1004')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да, доставлено'));
      await tester.pumpAndSettle();

      expect(find.text('#A-1027'), findsNothing);
      expect(find.text('Нет заказов в пути'), findsOneWidget);
    },
  );
}
