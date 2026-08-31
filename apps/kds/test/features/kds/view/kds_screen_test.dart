import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/kds/bloc/kds_orders_bloc.dart';
import 'package:kds/features/kds/bloc/kds_orders_event.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/view/kds_screen.dart';
import 'package:kds/features/kds/view/widgets/order_card.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Future<(KdsOrdersBloc, TestKdsOrdersRepository)> pumpScreen(
    WidgetTester tester, {
    List<KdsOrder> orders = const [],
    void Function(List<KdsOrder>)? onNewOrders,
  }) async {
    final repository = TestKdsOrdersRepository(orders: orders);
    final bloc = KdsOrdersBloc(repository: repository, pollInterval: null);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: KdsScreen(onNewOrders: onNewOrders, now: kNow),
        ),
      ),
    );
    bloc.add(const KdsOrdersStarted(branchId: 'branch-central'));
    await tester.pumpAndSettle();
    return (bloc, repository);
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
    final (_, repository) = await pumpScreen(
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
    final (_, repository) = await pumpScreen(tester);
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
    final (bloc, repository) = await pumpScreen(
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
}
