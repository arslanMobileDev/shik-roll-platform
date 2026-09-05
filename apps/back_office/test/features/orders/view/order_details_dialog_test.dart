import 'package:back_office/features/orders/bloc/orders_journal_bloc.dart';
import 'package:back_office/features/orders/bloc/orders_journal_event.dart';
import 'package:back_office/features/orders/data/fake_orders_repository.dart';
import 'package:back_office/features/orders/view/orders_journal_screen.dart';
import 'package:back_office/features/orders/view/widgets/order_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OrdersJournalBloc bloc;

  tearDown(() async {
    await bloc.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    bloc =
        OrdersJournalBloc(
            repository: FakeOrdersRepository(latency: Duration.zero),
          )
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

  testWidgets('shows receipt composition with modifiers and totals',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('orderRow-ord-2')));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsDialog), findsOneWidget);
    expect(find.text('Состав чека'), findsOneWidget);
    expect(find.text('ШИК бургер × 1'), findsOneWidget);
    // Modifier line and its price delta.
    expect(find.text('+ Доп. сыр чеддер × 1'), findsOneWidget);
    expect(find.textContaining('60,00'), findsOneWidget);
    expect(find.text('Подытог'), findsOneWidget);
    expect(find.text('Итого'), findsOneWidget);
    expect(find.textContaining('578,00'), findsWidgets);
  });

  testWidgets('shows 54-FZ payment data of a paid order', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('orderRow-ord-2')));
    await tester.pumpAndSettle();

    expect(find.text('Оплата (54-ФЗ)'), findsOneWidget);
    expect(find.text('ЮKassa'), findsOneWidget);
    expect(find.text('Оплачен'), findsOneWidget);
    expect(find.text('Ключ идемпотентности'), findsOneWidget);
    expect(find.text('ord-2-payment'), findsOneWidget);
    expect(
      find.text('2f9a1c00-0015-5000-9000-1d3f5a7b9c01'),
      findsOneWidget,
    );
  });

  testWidgets('shows placeholder when no payment is registered',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('orderRow-ord-1')));
    await tester.pumpAndSettle();

    expect(find.text('Платёж не зарегистрирован'), findsOneWidget);
  });

  testWidgets('shows cancelled payment of a cancelled order', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('orders.statusFilter.CANCELLED')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('orderRow-ord-6')));
    await tester.pumpAndSettle();

    expect(find.text('Отменён'), findsWidgets);
    expect(find.text('Клиент отменил по телефону'), findsOneWidget);
  });
}
