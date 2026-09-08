import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/features/orders/widgets/courier_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fakes.dart';

Widget buildCard(
  CourierOrder order, {
  VoidCallback? onClaim,
  VoidCallback? onStart,
  VoidCallback? onComplete,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CourierOrderCard(
          order: order,
          updating: false,
          onClaim: onClaim,
          onStart: onStart,
          onComplete: onComplete,
          onTap: onTap,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows number, total, payment badge, createdAt and address', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard(makeOrder(id: '1024')));

    expect(find.text('#A-1024'), findsOneWidget);
    expect(find.text('1 250 ₽'), findsOneWidget);
    expect(find.text('Требуется расчет'), findsOneWidget);
    expect(find.text('12:05'), findsOneWidget);
    expect(find.text('ул. Баумана, 58'), findsOneWidget);
    expect(find.text('кв. 12 · под. 3 · эт. 5 · домофон 127'), findsOneWidget);
    expect(find.text('Позвонить за 5 минут, спит ребенок'), findsOneWidget);
  });

  testWidgets('online payment badge reads «Оплачено онлайн»', (tester) async {
    await tester.pumpWidget(
      buildCard(makeOrder(id: '1', paymentMethod: PaymentMethod.onlinePaid)),
    );

    expect(find.text('Оплачено онлайн'), findsOneWidget);
    expect(find.text('Требуется расчет'), findsNothing);
  });

  testWidgets('unassigned READY order fires the claim callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(makeOrder(id: '1'), onClaim: () => tapped = true),
    );

    await tester.tap(find.text('Взять доставку'));
    expect(tapped, isTrue);
  });

  testWidgets('own READY order fires the start callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(
        makeOrder(id: '1', courierId: testCourier.id),
        onStart: () => tapped = true,
      ),
    );

    await tester.tap(find.text('В пути'));
    expect(tapped, isTrue);
  });

  testWidgets('COOKING order shows «Ещё готовится» without action', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(makeOrder(id: '1', status: OrderStatus.cooking)),
    );

    expect(find.text('Ещё готовится'), findsOneWidget);
    expect(find.text('Взять доставку'), findsNothing);
    expect(find.text('Доставлен'), findsNothing);
  });

  testWidgets('own ON_WAY order fires the complete callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(
        makeOrder(
          id: '1',
          status: OrderStatus.onWay,
          courierId: testCourier.id,
        ),
        onComplete: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Доставлен'));
    expect(tapped, isTrue);
  });

  testWidgets('card tap fires onTap callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(makeOrder(id: '1'), onTap: () => tapped = true),
    );

    await tester.tap(find.text('#A-1'));
    expect(tapped, isTrue);
  });
}
