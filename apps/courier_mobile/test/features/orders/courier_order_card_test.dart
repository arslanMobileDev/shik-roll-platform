import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/features/orders/widgets/courier_order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fakes.dart';

Widget buildCard(
  CourierOrder order, {
  VoidCallback? onPickup,
  VoidCallback? onComplete,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CourierOrderCard(
          order: order,
          updating: false,
          onPickup: onPickup,
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

  testWidgets('READY order fires «Взять заказ» callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(makeOrder(id: '1'), onPickup: () => tapped = true),
    );

    await tester.tap(find.text('Взять заказ'));
    expect(tapped, isTrue);
  });

  testWidgets('COOKING order shows «Ещё готовится» without action', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(makeOrder(id: '1', status: OrderStatus.cooking)),
    );

    expect(find.text('Ещё готовится'), findsOneWidget);
    expect(find.text('Взять заказ'), findsNothing);
    expect(find.text('Заказ доставлен'), findsNothing);
  });

  testWidgets('ON_WAY order fires «Заказ доставлен» callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildCard(
        makeOrder(id: '1', status: OrderStatus.onWay),
        onComplete: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Заказ доставлен'));
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
