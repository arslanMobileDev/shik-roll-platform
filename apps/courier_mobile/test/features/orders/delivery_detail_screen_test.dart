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
  testWidgets('tapping a card opens details with full address and comment', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#A-1024'));
    await tester.pumpAndSettle();

    expect(find.text('Заказ #A-1024'), findsOneWidget);
    expect(find.text('Адрес доставки'), findsOneWidget);
    expect(find.text('ул. Баумана, 58'), findsOneWidget);
    expect(find.text('кв. 12 · под. 3 · эт. 5 · домофон 127'), findsOneWidget);
    expect(find.text('Комментарий клиента'), findsOneWidget);
    expect(find.text('Позвонить за 5 минут, спит ребенок'), findsOneWidget);
    expect(find.text('Создан в 12:05'), findsOneWidget);
    expect(find.text('Требуется расчет'), findsOneWidget);
    expect(find.text('Готов к выдаче'), findsOneWidget);
    expect(find.byKey(const Key('detail_call_client')), findsOneWidget);
    expect(find.text('Взять заказ'), findsOneWidget);
  });

  testWidgets('«Взять заказ» switches detail action to «Заказ доставлен»', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#A-1024'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail_take_order-1001')));
    await tester.pumpAndSettle();

    expect(find.text('В пути'), findsOneWidget);
    expect(find.text('Заказ доставлен'), findsOneWidget);
    expect(find.text('Взять заказ'), findsNothing);
  });

  testWidgets('confirming «Заказ доставлен» pops back to the list', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мои в пути (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#A-1027'));
    await tester.pumpAndSettle();
    expect(find.text('Заказ #A-1027'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail_complete_order-1004')));
    await tester.pumpAndSettle();
    expect(find.text('Заказ #A-1027 доставлен?'), findsOneWidget);

    await tester.tap(find.text('Да, доставлено'));
    await tester.pumpAndSettle();

    // Detail closed; the completed order is gone from the active list.
    expect(find.text('Заказ #A-1027'), findsNothing);
    expect(find.text('Нет заказов в пути'), findsOneWidget);
  });
}
