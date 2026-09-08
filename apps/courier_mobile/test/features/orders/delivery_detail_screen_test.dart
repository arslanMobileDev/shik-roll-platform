import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/data/repositories/courier_repository.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/location/data/courier_location_repository.dart';
import 'package:courier_mobile/features/orders/view/courier_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fakes.dart';

Widget buildScreen(CourierRepository repository) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<CourierRepository>.value(value: repository),
      RepositoryProvider<CourierLocationRepository>.value(
        value: FakeCourierLocationRepository(),
      ),
    ],
    child: MaterialApp(
      home: CourierOrdersScreen(
        session: testSession,
        locationSource: FakeLocationSource(),
      ),
    ),
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
    expect(find.byKey(const Key('detail_claim_order-1001')), findsOneWidget);
  });

  testWidgets('full lifecycle: claim -> start -> complete pops to the list', (
    tester,
  ) async {
    final repo = FakeCourierRepository(
      seedOrders: [
        makeOrder(id: 'order-1'),
        makeOrder(id: 'order-2', status: OrderStatus.cooking),
      ],
    );
    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    // Unassigned READY: «Взять доставку» (claim).
    await tester.tap(find.text('#A-order-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_claim_order-1')));
    await tester.pumpAndSettle();

    // Own READY: «В пути».
    expect(find.byKey(const Key('detail_start_order-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail_start_order-1')));
    await tester.pumpAndSettle();

    // Own ON_WAY: «Доставлен» with confirmation.
    expect(find.byKey(const Key('detail_complete_order-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail_complete_order-1')));
    await tester.pumpAndSettle();
    expect(find.text('Заказ #A-order-1 доставлен?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_complete_button')));
    await tester.pumpAndSettle();

    // Detail popped; the delivered order is gone from the branch list.
    expect(find.text('Заказ #A-order-1'), findsNothing);
    expect(find.text('#A-order-1'), findsNothing);
    expect(find.text('#A-order-2'), findsOneWidget);
  });

  testWidgets('own ON_WAY order completes from the mine tab', (tester) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мой активный заказ'));
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
    expect(find.text('Нет активного заказа'), findsOneWidget);
  });
}
