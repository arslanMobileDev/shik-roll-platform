import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/theme/app_colors.dart';
import 'package:kds/features/kds/view/widgets/order_delay_timer.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  group('OrderDelayTimer.bandFor', () {
    test('under 10 minutes is onTime (green)', () {
      expect(
        OrderDelayTimer.bandFor(const Duration(minutes: 0)),
        DelayBand.onTime,
      );
      expect(
        OrderDelayTimer.bandFor(const Duration(minutes: 9, seconds: 59)),
        DelayBand.onTime,
      );
    });

    test('10–20 minutes is warning (yellow)', () {
      expect(
        OrderDelayTimer.bandFor(const Duration(minutes: 10)),
        DelayBand.warning,
      );
      expect(
        OrderDelayTimer.bandFor(const Duration(minutes: 20)),
        DelayBand.warning,
      );
    });

    test('over 20 minutes is late (red)', () {
      expect(
        OrderDelayTimer.bandFor(const Duration(minutes: 21)),
        DelayBand.late,
      );
      expect(OrderDelayTimer.bandFor(const Duration(hours: 2)), DelayBand.late);
    });
  });

  group('OrderDelayTimer widget', () {
    Color renderedBackground(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.byKey(const Key('order-delay-timer')),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    Future<void> pumpTimer(WidgetTester tester, Duration age) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderDelayTimer(createdAt: kNow.subtract(age), now: kNow),
          ),
        ),
      );
    }

    testWidgets('renders green under 10 minutes', (tester) async {
      await pumpTimer(tester, const Duration(minutes: 5));
      expect(renderedBackground(tester), AppColors.timerOnTimeContainer);
      expect(find.text('5 мин'), findsOneWidget);
    });

    testWidgets('renders yellow between 10 and 20 minutes', (tester) async {
      await pumpTimer(tester, const Duration(minutes: 15));
      expect(renderedBackground(tester), AppColors.timerWarningContainer);
      expect(find.text('15 мин'), findsOneWidget);
    });

    testWidgets('renders red over 20 minutes', (tester) async {
      await pumpTimer(tester, const Duration(minutes: 34));
      expect(renderedBackground(tester), AppColors.timerLateContainer);
      expect(find.text('34 мин'), findsOneWidget);
    });

    testWidgets('formats hours for very old orders', (tester) async {
      await pumpTimer(tester, const Duration(hours: 1, minutes: 12));
      expect(find.text('1 ч 12 мин'), findsOneWidget);
    });
  });
}
