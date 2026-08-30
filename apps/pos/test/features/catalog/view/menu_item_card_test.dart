import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/features/catalog/view/widgets/menu_item_card.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 240, child: child))),
    );
  }

  group('MenuItemCard', () {
    testWidgets('renders name, weight and formatted RUB price', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(MenuItemCard(item: testMenuItem(), onTap: (_) {})),
      );

      expect(find.text('Филадельфия'), findsOneWidget);
      expect(find.text('250 г'), findsOneWidget);
      expect(find.textContaining('390,00'), findsOneWidget);
      expect(find.textContaining('₽'), findsOneWidget);
    });

    testWidgets('tap on an available item fires the callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(MenuItemCard(item: testMenuItem(), onTap: (_) => taps++)),
      );

      await tester.tap(find.byType(MenuItemCard));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('shows halal badge for halal items', (tester) async {
      await tester.pumpWidget(
        wrap(MenuItemCard(item: testMenuItem(isHalal: true), onTap: (_) {})),
      );

      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('shows stop-list badge and blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          MenuItemCard(
            item: testMenuItem(stopListed: true, stopReason: 'Нет лосося'),
            onTap: (_) => taps++,
          ),
        ),
      );

      expect(find.text('Стоп-лист'), findsOneWidget);

      await tester.tap(find.byType(MenuItemCard));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('shows unavailable badge and blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          MenuItemCard(
            item: testMenuItem(isAvailable: false),
            onTap: (_) => taps++,
          ),
        ),
      );

      expect(find.text('Недоступно'), findsOneWidget);

      await tester.tap(find.byType(MenuItemCard));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('shows merchandising chips', (tester) async {
      await tester.pumpWidget(
        wrap(
          MenuItemCard(
            item: testMenuItem(isPopular: true, isNew: true),
            onTap: (_) {},
          ),
        ),
      );

      expect(find.text('Хит'), findsOneWidget);
      expect(find.text('Новинка'), findsOneWidget);
    });
  });
}
