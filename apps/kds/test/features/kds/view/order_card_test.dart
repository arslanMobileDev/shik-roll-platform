import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/theme/app_colors.dart';
import 'package:kds/core/widgets/halal_status_badge.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/view/widgets/order_card.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    KdsOrder order, {
    KdsOrderAction? onAction,
    bool isFresh = false,
    bool isPending = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderCard(
              order: order,
              onAction: onAction ?? (_) {},
              isFresh: isFresh,
              isPending: isPending,
              now: kNow,
            ),
          ),
        ),
      ),
    );
  }

  group('OrderCard content', () {
    testWidgets('shows number, type badge, halal badge, items and modifiers', (
      tester,
    ) async {
      await pumpCard(
        tester,
        buildOrder(
          orderNumber: '2042',
          type: KdsOrderType.dineIn,
          tableNumber: '7',
          items: [
            buildItem(
              name: 'Филадельфия классик',
              quantity: 2,
              modifiers: [
                buildModifier(name: 'Соус унаги'),
                buildModifier(id: 'mod-2', name: 'Икра тобико', quantity: 2),
              ],
            ),
            buildItem(id: 'item-2', name: 'Мисо-суп'),
          ],
        ),
      );

      expect(find.text('#2042'), findsOneWidget);
      expect(find.text('Зал · стол 7'), findsOneWidget);
      expect(find.byType(HalalStatusBadge), findsOneWidget);
      expect(find.text('100% HALAL'), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
      expect(find.text('Филадельфия классик'), findsOneWidget);
      expect(find.text('• Соус унаги'), findsOneWidget);
      expect(find.text('• Икра тобико ×2'), findsOneWidget);
      expect(find.text('Мисо-суп'), findsOneWidget);
    });

    testWidgets('shows takeaway type and customer comment', (tester) async {
      await pumpCard(
        tester,
        buildOrder(
          type: KdsOrderType.takeaway,
          comment: 'Без васаби, пожалуйста',
        ),
      );

      expect(find.text('С собой'), findsOneWidget);
      expect(find.text('Без васаби, пожалуйста'), findsOneWidget);
    });

    testWidgets('shows delivery type', (tester) async {
      await pumpCard(tester, buildOrder(type: KdsOrderType.delivery));
      expect(find.text('Доставка'), findsOneWidget);
    });

    testWidgets('fresh order is highlighted with the brand border', (
      tester,
    ) async {
      await pumpCard(tester, buildOrder(), isFresh: true);
      final container = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('#1001'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border!.top.color, AppColors.primary);
      expect(decoration.border!.top.width, 2);
    });
  });

  group('OrderCard actions', () {
    testWidgets('queued order offers «В работу» → COOKING', (tester) async {
      KdsOrderStatus? requested;
      await pumpCard(
        tester,
        buildOrder(status: KdsOrderStatus.newOrder),
        onAction: (status) => requested = status,
      );

      final button = find.byKey(const Key('order-action-order-1'));
      expect(
        find.descendant(of: button, matching: find.text('В работу')),
        findsOneWidget,
      );
      await tester.tap(button);
      expect(requested, KdsOrderStatus.cooking);
    });

    testWidgets('confirmed order also offers «В работу»', (tester) async {
      await pumpCard(tester, buildOrder(status: KdsOrderStatus.confirmed));
      expect(find.text('В работу'), findsOneWidget);
    });

    testWidgets('cooking order offers «Готово» → READY', (tester) async {
      KdsOrderStatus? requested;
      await pumpCard(
        tester,
        buildOrder(status: KdsOrderStatus.cooking),
        onAction: (status) => requested = status,
      );

      await tester.tap(find.byKey(const Key('order-action-order-1')));
      expect(find.text('Готово'), findsOneWidget);
      expect(requested, KdsOrderStatus.ready);
    });

    testWidgets('ready order offers «Выдано» → COMPLETED', (tester) async {
      KdsOrderStatus? requested;
      await pumpCard(
        tester,
        buildOrder(status: KdsOrderStatus.ready),
        onAction: (status) => requested = status,
      );

      await tester.tap(find.byKey(const Key('order-action-order-1')));
      expect(find.text('Выдано'), findsOneWidget);
      expect(requested, KdsOrderStatus.completed);
    });

    testWidgets('pending order disables the button and shows a spinner', (
      tester,
    ) async {
      var tapped = false;
      await pumpCard(
        tester,
        buildOrder(),
        onAction: (_) => tapped = true,
        isPending: true,
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('order-action-order-1')),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(const Key('order-action-order-1')));
      expect(tapped, isFalse);
    });
  });
}
