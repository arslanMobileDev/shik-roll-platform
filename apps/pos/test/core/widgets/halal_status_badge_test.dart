import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/widgets/halal_status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  group('HalalStatusBadge', () {
    testWidgets('renders HALAL label when item is halal', (tester) async {
      await tester.pumpWidget(
        wrap(const HalalStatusBadge(isHalal: true)),
      );

      expect(find.text('HALAL'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('renders nothing when item is not halal', (tester) async {
      await tester.pumpWidget(
        wrap(const HalalStatusBadge(isHalal: false)),
      );

      expect(find.text('HALAL'), findsNothing);
      expect(find.byIcon(Icons.verified_outlined), findsNothing);
    });

    testWidgets('compact variant hides the label but keeps the icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const HalalStatusBadge(isHalal: true, compact: true)),
      );

      expect(find.text('HALAL'), findsNothing);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('exposes a semantic label for screen readers', (tester) async {
      await tester.pumpWidget(
        wrap(const HalalStatusBadge(isHalal: true)),
      );

      expect(
        tester.getSemantics(find.byType(HalalStatusBadge)),
        matchesSemantics(label: 'Халяль'),
      );
    });
  });
}
