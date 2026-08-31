import 'package:customer_mobile/core/widgets/halal_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HalalStatusBadge renders HALAL label when isHalal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HalalStatusBadge(isHalal: true),
        ),
      ),
    );
    expect(find.text('HALAL'), findsOneWidget);
  });

  testWidgets('HalalStatusBadge collapses to nothing when not halal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HalalStatusBadge(isHalal: false),
        ),
      ),
    );
    expect(find.text('HALAL'), findsNothing);
    // Folds into a zero-size placeholder.
    expect(find.byType(HalalStatusBadge), findsOneWidget);
  });
}
