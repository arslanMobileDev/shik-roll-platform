import 'package:back_office/core/utils/money.dart';
import 'package:back_office/features/orders/bloc/orders_journal_bloc.dart';
import 'package:back_office/features/orders/bloc/orders_journal_event.dart';
import 'package:back_office/features/orders/data/fake_orders_repository.dart';
import 'package:back_office/features/orders/data/models/order.dart';
import 'package:back_office/features/orders/view/orders_journal_screen.dart';
import 'package:back_office/features/orders/view/widgets/order_details_dialog.dart';
import 'package:back_office/features/orders/view/widgets/orders_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _order = Order(
  id: 'ord-1',
  orderNumber: 'A-1042',
  status: OrderStatus.cooking,
  type: OrderType.dineIn,
  brandId: 'brand',
  branchId: 'branch-center',
  subtotalAmount: const Money(84800),
  totalAmount: const Money(84800),
  currency: 'RUB',
  createdAt: DateTime(2026, 9, 5, 14, 30),
  items: const [
    OrderItem(
      id: 'i1',
      menuItemId: 'm1',
      name: 'Филадельфия',
      quantity: 1,
      unitPrice: Money(34900),
      totalAmount: Money(34900),
    ),
  ],
);

void main() {
  Future<List<Order>> pumpTable(WidgetTester tester, Size size) async {
    final opened = <Order>[];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrdersTable(
            orders: [_order],
            onOpenDetails: opened.add,
          ),
        ),
      ),
    );
    return opened;
  }

  testWidgets('390px renders an order card that opens the details',
      (tester) async {
    final opened = await pumpTable(tester, const Size(390, 844));

    expect(find.text('Заказ'), findsNothing); // desktop column header
    expect(find.text('Состав'), findsNothing);
    expect(find.byKey(const ValueKey('orderRow-ord-1')), findsOneWidget);
    expect(find.text('№ A-1042'), findsOneWidget);
    expect(find.text('Готовится'), findsOneWidget);
    expect(find.textContaining('05.09.2026 · 14:30'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('orderRow-ord-1')));
    await tester.pump();
    expect(opened.single.id, 'ord-1');
  });

  testWidgets('1600px keeps the table', (tester) async {
    await pumpTable(tester, const Size(1600, 1000));

    expect(find.text('Заказ'), findsOneWidget);
    expect(find.text('Состав'), findsOneWidget);
    expect(find.byKey(const ValueKey('orderRow-ord-1')), findsOneWidget);
  });

  testWidgets('390px keeps the journal screen working', (tester) async {
    await pumpScreen(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('orderRow-ord-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('orderRow-ord-1')));
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailsDialog), findsOneWidget);
  });

  // UI-303: both chip rows (status, date) become single scrolling lines on a
  // phone, stacked one under the other.
  testWidgets('390px keeps both chip rows on one scrolling line each',
      (tester) async {
    await pumpScreen(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(_wrapAround(const ValueKey('orders.statusFilter.all')), findsNothing);
    expect(_wrapAround(const ValueKey('orders.dateFilter.all')), findsNothing);
    expect(chipBaselines(tester), hasLength(2)); // status row + date row
  });

  testWidgets('1600px still wraps both chip rows', (tester) async {
    await pumpScreen(tester, const Size(1600, 1000));

    expect(
      _wrapAround(const ValueKey('orders.statusFilter.all')),
      findsOneWidget,
    );
    expect(_wrapAround(const ValueKey('orders.dateFilter.all')), findsOneWidget);
  });
}

Future<void> pumpScreen(WidgetTester tester, Size size) async {
  final bloc = OrdersJournalBloc(
    repository: FakeOrdersRepository(latency: Duration.zero),
  )..add(const OrdersJournalRequested(branchId: 'branch-center'));
  addTearDown(bloc.close);
  tester.view.physicalSize = size;
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

/// The [Wrap] a chip row sits in — present on wide screens only.
Finder _wrapAround(ValueKey<String> chipKey) => find.ancestor(
  of: find.byKey(chipKey),
  matching: find.byType(Wrap),
);

/// Distinct vertical offsets among the chips: one entry per row of chips.
Set<double> chipBaselines(WidgetTester tester) {
  final chips = find.byType(ChoiceChip);
  return {
    for (var i = 0; i < chips.evaluate().length; i++)
      tester.getTopLeft(chips.at(i)).dy,
  };
}
