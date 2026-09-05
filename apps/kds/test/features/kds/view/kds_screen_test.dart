import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/kds/bloc/kds_orders_bloc.dart';
import 'package:kds/features/kds/bloc/kds_orders_event.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/view/kds_screen.dart';
import 'package:kds/features/kds/view/widgets/order_card.dart';
import 'package:kds/features/shift/bloc/cook_shift_cubit.dart';
import 'package:kds/features/shift/data/cook_shift_models.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Future<(KdsOrdersBloc, TestKdsOrdersRepository, CookShiftCubit)> pumpScreen(
    WidgetTester tester, {
    List<KdsOrder> orders = const [],
    List<ActiveCook> cooks = const [],
    void Function(List<KdsOrder>)? onNewOrders,
  }) async {
    // Primary KDS target: tablet 1024x768 landscape (AppBreakpoints).
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TestKdsOrdersRepository(orders: orders);
    final bloc = KdsOrdersBloc(repository: repository, pollInterval: null);
    final shiftCubit = CookShiftCubit(
      repository: TestCookShiftRepository(cooks: cooks),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: shiftCubit),
          ],
          child: KdsScreen(onNewOrders: onNewOrders, now: kNow),
        ),
      ),
    );
    bloc.add(const KdsOrdersStarted(branchId: 'branch-central'));
    await shiftCubit.load('branch-central');
    await tester.pumpAndSettle();
    return (bloc, repository, shiftCubit);
  }

  testWidgets('доска раскладывает заказы по трём колонкам', (tester) async {
    await pumpScreen(
      tester,
      orders: [
        buildOrder(
          id: 'q',
          orderNumber: '101',
          status: KdsOrderStatus.newOrder,
        ),
        buildOrder(
          id: 'c',
          orderNumber: '102',
          status: KdsOrderStatus.confirmed,
        ),
        buildOrder(id: 'k', orderNumber: '103', status: KdsOrderStatus.cooking),
        buildOrder(id: 'r', orderNumber: '104', status: KdsOrderStatus.ready),
        buildOrder(
          id: 'd',
          orderNumber: '105',
          status: KdsOrderStatus.completed,
        ),
      ],
    );

    expect(find.text('В очереди'), findsOneWidget);
    expect(find.text('Готовятся'), findsOneWidget);
    expect(find.text('Готовы'), findsOneWidget);
    // Счётчики в заголовках колонок: 2 / 1 / 1.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('#101'), findsOneWidget);
    expect(find.text('#104'), findsOneWidget);
    // COMPLETED на доске не показывается.
    expect(find.text('#105'), findsNothing);
  });

  testWidgets('тап «В работу» переводит заказ в колонку «Готовятся»', (
    tester,
  ) async {
    final (_, repository, _) = await pumpScreen(
      tester,
      orders: [
        buildOrder(
          id: 'a',
          orderNumber: '201',
          status: KdsOrderStatus.newOrder,
        ),
      ],
    );

    expect(find.text('В работу'), findsOneWidget);
    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(repository.statusCalls, [('a', KdsOrderStatus.cooking)]);
    // Карточка предлагает следующее действие колонки «Готовятся».
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('В работу'), findsNothing);
  });

  testWidgets('тап «Выдано» убирает заказ с доски', (tester) async {
    await pumpScreen(
      tester,
      orders: [
        buildOrder(id: 'a', orderNumber: '202', status: KdsOrderStatus.ready),
      ],
    );

    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(find.text('#202'), findsNothing);
    expect(find.byType(OrderCard), findsNothing);
  });

  testWidgets('кнопка «Обновить» перезапрашивает заказы', (tester) async {
    final (_, repository, _) = await pumpScreen(tester);
    expect(find.byType(OrderCard), findsNothing);

    repository.orders.add(
      buildOrder(id: 'n', orderNumber: '301', status: KdsOrderStatus.newOrder),
    );
    await tester.tap(find.byKey(const Key('kds-refresh-button')));
    await tester.pumpAndSettle();

    expect(find.text('#301'), findsOneWidget);
  });

  testWidgets('новый заказ: звуковой сигнал и снэкбар', (tester) async {
    final alerted = <List<KdsOrder>>[];
    final (bloc, repository, _) = await pumpScreen(
      tester,
      onNewOrders: alerted.add,
    );

    repository.orders.add(
      buildOrder(
        id: 'fresh',
        orderNumber: '401',
        status: KdsOrderStatus.newOrder,
      ),
    );
    bloc.add(const KdsOrdersPollTicked());
    await tester.pumpAndSettle();

    expect(alerted, hasLength(1));
    expect(alerted.single.map((o) => o.id), ['fresh']);
    expect(find.text('Новый заказ: #401'), findsOneWidget);
    // Карточка подсвечена.
    final card = tester.widget<OrderCard>(
      find.byKey(const Key('order-card-fresh')),
    );
    expect(card.isFresh, isTrue);

    // «OK» снимает подсветку.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final cardAfter = tester.widget<OrderCard>(
      find.byKey(const Key('order-card-fresh')),
    );
    expect(cardAfter.isFresh, isFalse);
  });

  testWidgets('выбранный повар: cookId/shiftId уходят в смену статуса', (
    tester,
  ) async {
    final (_, repository, shiftCubit) = await pumpScreen(
      tester,
      orders: [
        buildOrder(
          id: 'a',
          orderNumber: '501',
          status: KdsOrderStatus.confirmed,
        ),
      ],
      cooks: [buildCook()],
    );
    shiftCubit.selectCook('cook-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(repository.attributionCalls, [('a', 'cook-1', 'shift-1')]);
  });

  testWidgets('без повара: только shiftId, без cookId', (tester) async {
    final (_, repository, _) = await pumpScreen(
      tester,
      orders: [
        buildOrder(
          id: 'a',
          orderNumber: '502',
          status: KdsOrderStatus.confirmed,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(repository.attributionCalls, [('a', null, 'shift-1')]);
  });

  testWidgets('тап «Выдано» инкрементирует личный счётчик повара в шапке', (
    tester,
  ) async {
    final (_, _, shiftCubit) = await pumpScreen(
      tester,
      orders: [
        buildOrder(id: 'a', orderNumber: '503', status: KdsOrderStatus.ready),
      ],
      cooks: [buildCook(completedOrders: 7, avgPrepSeconds: 600)],
    );
    shiftCubit.selectCook('cook-1');
    await tester.pumpAndSettle();

    expect(find.text('Выполнено за смену: 7 шт. · ~10 мин'), findsOneWidget);

    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(shiftCubit.state.currentCook?.completedOrders, 8);
    // (600·7 + 300) / 8 = 562.5 → 563с ≈ 9 мин.
    expect(find.text('Выполнено за смену: 8 шт. · ~9 мин'), findsOneWidget);
  });
}
