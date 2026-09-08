import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/data/repositories/courier_repository.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/location/bloc/location_tracking_cubit.dart';
import 'package:courier_mobile/features/location/bloc/location_tracking_state.dart';
import 'package:courier_mobile/features/location/data/courier_location_repository.dart';
import 'package:courier_mobile/features/orders/view/courier_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fakes.dart';

Widget buildScreen(
  CourierRepository repository, {
  FakeLocationSource? locationSource,
}) {
  final source = locationSource ?? FakeLocationSource();
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<CourierRepository>.value(value: repository),
      RepositoryProvider<CourierLocationRepository>.value(
        value: FakeCourierLocationRepository(),
      ),
    ],
    child: MaterialApp(
      home: CourierOrdersScreen(session: testSession, locationSource: source),
    ),
  );
}

void main() {
  testWidgets('available tab shows READY and COOKING branch orders', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Доступные (2)'), findsOneWidget);
    expect(find.text('#A-1024'), findsOneWidget);
    expect(find.text('#A-1025'), findsOneWidget);
    expect(find.text('ул. Баумана, 58'), findsOneWidget);
    expect(find.text('кв. 12 · под. 3 · эт. 5 · домофон 127'), findsOneWidget);
    expect(find.text('Позвонить за 5 минут, спит ребенок'), findsOneWidget);
    expect(find.text('1 250 ₽'), findsOneWidget);
    expect(find.text('Требуется расчет'), findsOneWidget);
    expect(find.text('Оплачено онлайн'), findsOneWidget);

    // READY order can be claimed; COOKING one is still on the kitchen.
    expect(find.text('Взять доставку'), findsOneWidget);
    expect(find.text('Ещё готовится'), findsOneWidget);

    // SSE has not delivered an event yet — the chip shows reconnecting.
    expect(find.text('Подключение…'), findsOneWidget);
  });

  testWidgets('mine tab shows the own ON_WAY order', (tester) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мой активный заказ'));
    await tester.pumpAndSettle();

    expect(find.text('#A-1027'), findsOneWidget);
    expect(find.text('#A-1024'), findsNothing);
    expect(find.text('Доставлен'), findsOneWidget);
  });

  testWidgets('own ON_WAY order starts foreground location tracking', (
    tester,
  ) async {
    final source = FakeLocationSource();
    await tester.pumpWidget(
      buildScreen(FakeCourierRepository(), locationSource: source),
    );
    await tester.pumpAndSettle();

    // whileInUse permission — tracking runs foreground-only with a warning.
    // Read from a descendant element: the cubit is provided INSIDE the
    // screen's own build, below the CourierOrdersScreen element.
    final cubit = tester
        .element(find.byType(Scaffold))
        .read<LocationTrackingCubit>();
    expect(cubit.state.status, CourierTrackingStatus.trackingForegroundOnly);
    expect(cubit.state.activeOrderId, 'order-1004');
    expect(source.streamSubscriptions, 1);
    expect(find.byKey(const Key('location_warning')), findsOneWidget);
  });

  testWidgets('«Доставлен» requires confirmation and completes the order', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мой активный заказ'));
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
    expect(find.text('Нет активного заказа'), findsOneWidget);
  });

  testWidgets('claim conflict shows a snackbar and keeps the order', (
    tester,
  ) async {
    // Default seeds already have an own ON_WAY order — the fake repository
    // rejects a second active delivery, so the claim rolls back.
    await tester.pumpWidget(buildScreen(FakeCourierRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('claim_order-1001')));
    await tester.pumpAndSettle();

    expect(find.text('Статус заказа изменился'), findsOneWidget);
    expect(find.text('#A-1024'), findsOneWidget);
  });

  testWidgets('successful claim moves the order to the mine tab', (
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

    await tester.tap(find.byKey(const Key('claim_order-1')));
    await tester.pumpAndSettle();

    expect(find.text('Доступные (1)'), findsOneWidget);

    await tester.tap(find.text('Мой активный заказ'));
    await tester.pumpAndSettle();
    expect(find.text('#A-order-1'), findsOneWidget);
    expect(find.text('В пути'), findsOneWidget);
  });
}
