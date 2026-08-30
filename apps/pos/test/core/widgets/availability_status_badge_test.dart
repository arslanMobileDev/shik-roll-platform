import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/widgets/availability_status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  group('AvailabilityStatusBadge', () {
    testWidgets('renders nothing when the item is available', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AvailabilityStatusBadge(status: AvailabilityStatus.available),
        ),
      );

      expect(find.text('Стоп-лист'), findsNothing);
      expect(find.text('Недоступно'), findsNothing);
    });

    testWidgets('renders stop-list badge with block icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AvailabilityStatusBadge(
            status: AvailabilityStatus.stopListed,
          ),
        ),
      );

      expect(find.text('Стоп-лист'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('renders unavailable badge for branch-disabled items', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const AvailabilityStatusBadge(
            status: AvailabilityStatus.unavailable,
          ),
        ),
      );

      expect(find.text('Недоступно'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('stop-list reason is exposed via tooltip', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AvailabilityStatusBadge(
            status: AvailabilityStatus.stopListed,
            stopListReason: 'Нет ингредиентов',
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Нет ингредиентов');
    });
  });
}
