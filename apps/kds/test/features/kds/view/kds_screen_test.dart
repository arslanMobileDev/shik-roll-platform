import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/storage/kitchen_session_store.dart';
import 'package:kds/features/auth/bloc/kitchen_auth_cubit.dart';
import 'package:kds/features/kds/bloc/kds_orders_bloc.dart';
import 'package:kds/features/kds/bloc/kds_orders_event.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/data/kitchen_events_client.dart';
import 'package:kds/features/kds/view/kds_screen.dart';
import 'package:kds/features/kds/view/widgets/order_card.dart';
import 'package:kds/features/shift/bloc/cook_shift_cubit.dart';
import 'package:kds/features/shift/data/cook_shift_models.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Future<
    (
      KdsOrdersBloc,
      TestKdsOrdersRepository,
      CookShiftCubit,
      KitchenAuthCubit,
      TestKitchenEventsClient,
      TestKitchenAlertService,
    )
  >
  pumpScreen(
    WidgetTester tester, {
    List<KdsOrder> orders = const [],
    List<ActiveCook> cooks = const [],
  }) async {
    // Primary KDS target: tablet 1024x768 landscape (AppBreakpoints).
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TestKdsOrdersRepository(orders: orders);
    final eventsClient = TestKitchenEventsClient();
    final alertService = TestKitchenAlertService();
    final bloc = KdsOrdersBloc(
      repository: repository,
      eventsClient: eventsClient,
      pollInterval: null,
      now: () => kNow,
    );
    final shiftCubit = CookShiftCubit(
      repository: TestCookShiftRepository(cooks: cooks),
    );
    final authCubit = KitchenAuthCubit(
      repository: TestKitchenAuthRepository(),
      storage: TestKitchenTokenStorage(),
      sessionStore: KitchenSessionStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: shiftCubit),
            BlocProvider.value(value: authCubit),
          ],
          child: KdsScreen(alertService: alertService, now: kNow),
        ),
      ),
    );
    bloc.add(const KdsOrdersStarted());
    await shiftCubit.load('branch-central');
    await tester.pumpAndSettle();
    return (
      bloc,
      repository,
      shiftCubit,
      authCubit,
      eventsClient,
      alertService,
    );
  }

  testWidgets('доска раскладывает заказы по трём колонкам', (tester) async {
    await pumpScreen(
      tester,
      orders: [
        buildOrder(id: 'q', orderNumber: '101'),
        buildOrder(id: 'c', orderNumber: '102'),
        buildOrder(
          id: 'k',
          orderNumber: '103',
          status: KdsOrderStatus.cooking,
          cookingStartedAt: kNow.subtract(const Duration(minutes: 4)),
        ),
        buildOrder(
          id: 'r',
          orderNumber: '104',
          status: KdsOrderStatus.ready,
          readyAt: kNow.subtract(const Duration(minutes: 2)),
        ),
        buildOrder(
          id: 'd',
          orderNumber: '105',
          status: KdsOrderStatus.completed,
        ),
        buildOrder(
          id: 'n',
          orderNumber: '106',
          status: KdsOrderStatus.newOrder,
        ),
      ],
    );

    expect(find.text('Новые'), findsOneWidget);
    expect(find.text('Готовятся'), findsOneWidget);
    expect(find.text('Готовы'), findsOneWidget);
    // Счётчики в заголовках колонок: 3 / 1 / 1.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('#101'), findsOneWidget);
    expect(find.text('#104'), findsOneWidget);
    // COMPLETED скрыт, а ON_DELIVERY заказ NEW сразу виден кухне.
    expect(find.text('#105'), findsNothing);
    expect(find.text('#106'), findsOneWidget);
  });

  testWidgets('тап «Начать готовить» переводит заказ в «Готовятся»', (
    tester,
  ) async {
    final (_, repository, _, _, _, _) = await pumpScreen(
      tester,
      orders: [buildOrder(id: 'a', orderNumber: '201', version: 3)],
    );

    expect(find.text('Начать готовить'), findsOneWidget);
    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(repository.statusCalls, [('a', KdsOrderStatus.cooking, 3)]);
    // Карточка предлагает следующее действие колонки «Готовятся».
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('Начать готовить'), findsNothing);
  });

  testWidgets('тап «Готово» переводит заказ в «Готовы», заказ остаётся', (
    tester,
  ) async {
    final (_, repository, _, _, _, _) = await pumpScreen(
      tester,
      orders: [
        buildOrder(
          id: 'a',
          orderNumber: '202',
          status: KdsOrderStatus.cooking,
          cookingStartedAt: kNow.subtract(const Duration(minutes: 6)),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(repository.statusCalls, [('a', KdsOrderStatus.ready, 1)]);
    // Заказ готов, но остаётся на доске: выдачу закрывают POS/курьер.
    expect(find.text('#202'), findsOneWidget);
    expect(find.text('Выдано'), findsNothing);
    expect(find.byKey(const Key('order-action-a')), findsNothing);
  });

  testWidgets('кнопка «Обновить» перезапрашивает заказы', (tester) async {
    final (_, repository, _, _, _, _) = await pumpScreen(tester);
    expect(find.byType(OrderCard), findsNothing);

    repository.orders.add(buildOrder(id: 'n', orderNumber: '301'));
    await tester.tap(find.byKey(const Key('kds-refresh-button')));
    await tester.pumpAndSettle();

    expect(find.text('#301'), findsOneWidget);
  });

  testWidgets('новый заказ по SSE: звуковой сигнал и снэкбар', (tester) async {
    final (bloc, _, _, _, eventsClient, alertService) = await pumpScreen(
      tester,
    );

    eventsClient.emitSignal(const KitchenStreamConnected());
    await tester.pump();
    eventsClient.emitSignal(
      KitchenOrderUpserted(
        order: buildOrder(id: 'fresh', orderNumber: '401', version: 1),
        orderVersion: 1,
        eventId: 'evt-401-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(alertService.notifyCounts, [1]);
    expect(find.text('Новый заказ: #401'), findsOneWidget);
    // Карточка подсвечена.
    final card = tester.widget<OrderCard>(
      find.byKey(const Key('order-card-fresh')),
    );
    expect(card.isFresh, isTrue);

    // «OK» снимает подсветку.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(bloc.state.freshOrderIds, isEmpty);
    final cardAfter = tester.widget<OrderCard>(
      find.byKey(const Key('order-card-fresh')),
    );
    expect(cardAfter.isFresh, isFalse);
  });

  testWidgets('индикатор соединения: connecting → live', (tester) async {
    final (_, _, _, _, eventsClient, _) = await pumpScreen(tester);

    expect(
      find.byKey(const Key('kds-connection-KdsConnectionStatus.connecting')),
      findsOneWidget,
    );

    eventsClient.emitSignal(const KitchenStreamConnected());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('kds-connection-KdsConnectionStatus.live')),
      findsOneWidget,
    );
  });

  testWidgets('mute-переключатель глушит звук станции', (tester) async {
    final (_, _, _, _, _, alertService) = await pumpScreen(tester);

    expect(alertService.muted, isFalse);
    await tester.tap(find.byKey(const Key('kds-mute-toggle')));
    await tester.pumpAndSettle();

    expect(alertService.muted, isTrue);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('выбранный повар: cookId/shiftId уходят в смену статуса', (
    tester,
  ) async {
    final (_, repository, shiftCubit, _, _, _) = await pumpScreen(
      tester,
      orders: [buildOrder(id: 'a', orderNumber: '501')],
      cooks: [buildCook()],
    );
    shiftCubit.selectCook('cook-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(repository.attributionCalls, [('a', 'cook-1', 'shift-1')]);
  });

  testWidgets('без повара: только shiftId, без cookId', (tester) async {
    final (_, repository, _, _, _, _) = await pumpScreen(
      tester,
      orders: [buildOrder(id: 'a', orderNumber: '502')],
    );

    await tester.tap(find.byKey(const Key('order-action-a')));
    await tester.pumpAndSettle();

    expect(repository.attributionCalls, [('a', null, 'shift-1')]);
  });

  testWidgets('logout из шапки разлогинивает терминал', (tester) async {
    final (_, _, _, authCubit, _, _) = await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('kds-logout-button')));
    await tester.pumpAndSettle();

    expect(authCubit.state, isA<KitchenUnauthenticated>());
  });
}
