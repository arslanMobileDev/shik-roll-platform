import 'package:back_office/features/orders/bloc/orders_journal_bloc.dart';
import 'package:back_office/features/orders/bloc/orders_journal_event.dart';
import 'package:back_office/features/orders/bloc/orders_journal_state.dart';
import 'package:back_office/features/orders/data/fake_orders_repository.dart';
import 'package:back_office/features/orders/view/orders_journal_screen.dart';
import 'package:back_office/features/orders/view/widgets/order_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeOrdersRepository repository;
  late OrdersJournalBloc bloc;

  setUp(() {
    repository = FakeOrdersRepository(latency: Duration.zero);
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Create the bloc and dispatch inside the test body so the fake
    // repository's Future.delayed lives in the test's FakeAsync zone.
    bloc = OrdersJournalBloc(repository: repository)
      ..add(const OrdersJournalRequested(branchId: 'branch-center'));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<OrdersJournalBloc>.value(
          value: bloc,
          child: const Scaffold(body: OrdersJournalScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders journal table with orders after load', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Журнал заказов'), findsOneWidget);
    expect(find.text('№ A-1042'), findsOneWidget);
    expect(find.text('№ A-1041'), findsOneWidget);
    expect(find.text('Показано 7 из 7'), findsOneWidget);
    // Status badges of seeded demo orders (labels also appear in filter chips).
    expect(find.text('Новый'), findsWidgets);
    expect(find.text('Готовится'), findsWidgets);
    expect(find.text('Отменён'), findsWidgets);
  });

  testWidgets('status filter refetches orders server-side', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('orders.statusFilter.COOKING')));
    await tester.pumpAndSettle();

    expect(find.text('№ A-1041'), findsOneWidget);
    expect(find.text('№ A-1042'), findsNothing);
    expect(bloc.state.statusFilter?.wireName, 'COOKING');

    await tester.tap(find.byKey(const ValueKey('orders.statusFilter.all')));
    await tester.pumpAndSettle();
    expect(find.text('№ A-1042'), findsOneWidget);
  });

  testWidgets('date filter keeps only orders of the period', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('orders.dateFilter.yesterday')));
    await tester.pump();

    expect(find.text('№ A-1036'), findsOneWidget);
    expect(find.text('№ A-1042'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('orders.dateFilter.all')));
    await tester.pump();
    expect(find.text('№ A-1042'), findsOneWidget);
  });

  testWidgets('row tap opens receipt details and closes them', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('orderRow-ord-1')));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsDialog), findsOneWidget);
    expect(find.text('Заказ № A-1042'), findsOneWidget);
    expect(find.text('Филадельфия классик × 1'), findsOneWidget);
    expect(find.text('Стол'), findsOneWidget);
    expect(bloc.state.selectedOrderId, 'ord-1');

    await tester.tap(find.byKey(const ValueKey('orderDetails.close')));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsDialog), findsNothing);
    expect(bloc.state.selectedOrderId, isNull);
    expect(bloc.state.paymentStatus, OrderPaymentStatus.idle);
  });
}
