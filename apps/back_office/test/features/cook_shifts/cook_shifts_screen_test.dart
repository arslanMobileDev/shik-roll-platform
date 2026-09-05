import 'package:back_office/features/cook_shifts/bloc/cook_shifts_cubit.dart';
import 'package:back_office/features/cook_shifts/data/cook_shift_models.dart';
import 'package:back_office/features/cook_shifts/view/cook_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_cook_shifts_repository.dart';

void main() {
  Future<(CookShiftsCubit, TestCookShiftsRepository)> pumpScreen(
    WidgetTester tester, {
    List<CookShiftRecord> shifts = const [],
    Object? fetchError,
    bool load = true,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TestCookShiftsRepository(shifts: shifts)
      ..fetchError = fetchError;
    final cubit = CookShiftsCubit(repository: repository);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: CookShiftsScreen()),
        ),
      ),
    );
    if (load) {
      await cubit.load('branch-center');
      await tester.pumpAndSettle();
    }
    return (cubit, repository);
  }

  testWidgets('таблица: повара, цех, метрики и бейджи статуса', (tester) async {
    await pumpScreen(
      tester,
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

    expect(find.text('Смены кухни'), findsOneWidget);
    expect(
      find.text('На линии сейчас: 1 · выдано заказов: 25 шт.'),
      findsOneWidget,
    );
    expect(find.text('Ахмед'), findsOneWidget);
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Сушист'), findsOneWidget);
    expect(find.text('Горячий цех'), findsOneWidget);
    expect(find.text('14 шт.'), findsOneWidget);
    expect(find.text('11 мин'), findsOneWidget);
    // Открытая смена: время закрытия и среднее время ещё неизвестны.
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('На смене'), findsOneWidget);
    expect(find.text('Смена закрыта'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shiftActiveBadge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shiftClosedBadge')),
      findsOneWidget,
    );
  });

  testWidgets('пустая история: заглушка', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Смен пока не было'), findsOneWidget);
  });

  testWidgets('ошибка загрузки: сообщение и повтор по кнопке', (tester) async {
    final (_, repository) = await pumpScreen(
      tester,
      fetchError: StateError('API 500'),
    );

    expect(find.textContaining('API 500'), findsOneWidget);
    expect(find.byKey(const Key('cookShiftsRetry')), findsOneWidget);

    repository.fetchError = null;
    repository.shifts = [buildShift()];
    await tester.tap(find.byKey(const Key('cookShiftsRetry')));
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, ['branch-center', 'branch-center']);
    expect(find.text('Ахмед'), findsOneWidget);
  });

  testWidgets('загрузка: спиннер', (tester) async {
    await pumpScreen(tester, load: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
