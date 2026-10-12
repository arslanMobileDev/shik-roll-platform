import 'package:back_office/features/cook_shifts/bloc/cook_shifts_cubit.dart';
import 'package:back_office/features/cook_shifts/data/cook_shift_models.dart';
import 'package:back_office/features/cook_shifts/view/cook_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_cook_shifts_repository.dart';

void main() {
  Future<CookShiftsCubit> pumpScreen(
    WidgetTester tester,
    Size size, {
    List<CookShiftRecord> shifts = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = CookShiftsCubit(
      repository: TestCookShiftsRepository(shifts: shifts),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: CookShiftsScreen()),
        ),
      ),
    );
    await cubit.load('branch-center');
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('390px renders shift cards, not the DataTable', (tester) async {
    await pumpScreen(
      tester,
      const Size(390, 844),
      shifts: [
        buildShift(
          id: 'active',
          cookName: 'Ахмед',
          completedOrders: 14,
          avgPrepSeconds: 11 * 60,
        ),
        buildShift(
          id: 'closed',
          cookName: 'Иван',
          role: CookRole.hotChef,
          clockOutAt: kShiftNow,
          completedOrders: 11,
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Терминал'), findsNothing); // desktop column header
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Ахмед'), findsOneWidget);
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('На смене'), findsOneWidget);
    expect(find.text('Смена закрыта'), findsOneWidget);
    // The badge keys and the metric strings are shared with the table.
    expect(find.byKey(const ValueKey('shiftActiveBadge')), findsOneWidget);
    expect(find.byKey(const ValueKey('shiftClosedBadge')), findsOneWidget);
    expect(find.textContaining('14 шт.'), findsOneWidget);
    expect(find.textContaining('11.0 мин'), findsOneWidget);
    expect(find.textContaining('Длительность'), findsNWidgets(2));
  });

  testWidgets('1600px keeps the DataTable', (tester) async {
    await pumpScreen(
      tester,
      const Size(1600, 1000),
      shifts: [buildShift()],
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Терминал'), findsOneWidget);
  });

  // UI-303: the period chips scroll sideways in one row on a phone instead of
  // stacking and pushing the shift cards off screen.
  testWidgets('390px keeps the period chips on one scrolling line',
      (tester) async {
    await pumpScreen(tester, const Size(390, 844), shifts: [buildShift()]);

    expect(tester.takeException(), isNull);
    expect(_wrapAroundPeriodChips(), findsNothing);
    expect(_periodChipBaselines(tester), hasLength(1));
  });

  testWidgets('1600px still wraps the period chips', (tester) async {
    await pumpScreen(tester, const Size(1600, 1000), shifts: [buildShift()]);

    expect(_wrapAroundPeriodChips(), findsOneWidget);
  });
}

/// The [Wrap] the period chips sit in — present on wide screens only. The
/// chips carry no keys, so the label is the handle. The metric `Wrap` inside a
/// shift card holds `Длительность …` texts, never `Сегодня`.
Finder _wrapAroundPeriodChips() => find.ancestor(
  of: find.text('Сегодня'),
  matching: find.byType(Wrap),
);

/// Distinct vertical offsets among the period chips: one entry means one row.
/// They are the only [ChoiceChip]s on the screen.
Set<double> _periodChipBaselines(WidgetTester tester) {
  final chips = find.byType(ChoiceChip);
  return {
    for (var i = 0; i < chips.evaluate().length; i++)
      tester.getTopLeft(chips.at(i)).dy,
  };
}
