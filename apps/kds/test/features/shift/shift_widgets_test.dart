import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/shift/bloc/cook_shift_cubit.dart';
import 'package:kds/features/shift/data/cook_shift_models.dart';
import 'package:kds/features/shift/view/widgets/cook_shift_header.dart';
import 'package:kds/features/shift/view/widgets/shift_production_badge.dart';
import 'package:kds/features/shift/view/widgets/shift_select_dialog.dart';

import '../../helpers/test_fixtures.dart';

void main() {
  Future<(CookShiftCubit, TestCookShiftRepository)> pumpHeader(
    WidgetTester tester, {
    List<ActiveCook> cooks = const [],
  }) async {
    // Desktop surface: the full header (name + role column) is visible.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TestCookShiftRepository(cooks: cooks);
    final cubit = CookShiftCubit(repository: repository);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            appBar: AppBar(actions: const [CookShiftHeader()]),
          ),
        ),
      ),
    );
    await cubit.load('branch-central');
    await tester.pumpAndSettle();
    return (cubit, repository);
  }

  testWidgets('без повара: кнопка «Выбрать смену» открывает диалог', (
    tester,
  ) async {
    await pumpHeader(tester, cooks: [buildCook()]);

    expect(find.text('Выбрать смену'), findsOneWidget);
    expect(find.byType(ShiftProductionBadge), findsNothing);

    await tester.tap(find.byKey(const Key('open-shift-select')));
    await tester.pumpAndSettle();

    expect(find.byType(ShiftSelectDialog), findsOneWidget);
    expect(find.text('На линии'), findsOneWidget);
    expect(find.text('Ахмед'), findsOneWidget);
  });

  testWidgets('выбор повара из списка: диалог закрывается, шапка обновляется', (
    tester,
  ) async {
    final (cubit, _) = await pumpHeader(
      tester,
      cooks: [
        buildCook(completedOrders: 7, avgPrepSeconds: 660),
        buildCook(id: 'cook-2', name: 'Иван', role: CookRole.hotChef),
      ],
    );

    await tester.tap(find.byKey(const Key('open-shift-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('select-cook-cook-1')));
    await tester.pumpAndSettle();

    expect(find.byType(ShiftSelectDialog), findsNothing);
    expect(cubit.state.currentCook?.id, 'cook-1');
    expect(find.text('Ахмед'), findsOneWidget);
    expect(find.text('Сушист'), findsOneWidget);
    // Бейдж выработки: 7 шт. и ~11 мин.
    expect(find.text('Выполнено за смену: 7 шт. · ~11 мин'), findsOneWidget);
  });

  testWidgets('валидация: PIN короче 4 цифр и пустое имя', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byKey(const Key('open-shift-select')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('shift-pin-field')), '111');
    await tester.tap(find.byKey(const Key('shift-clock-in-button')));
    await tester.pumpAndSettle();
    expect(find.text('Введите 4 цифры PIN'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('shift-pin-field')), '1111');
    await tester.tap(find.byKey(const Key('shift-clock-in-button')));
    await tester.pumpAndSettle();
    expect(find.text('Укажите имя повара'), findsOneWidget);
    expect(find.byType(ShiftSelectDialog), findsOneWidget);
  });

  testWidgets('clock-in по PIN: повар добавлен и выбран, диалог закрыт', (
    tester,
  ) async {
    final (cubit, repository) = await pumpHeader(tester);

    await tester.tap(find.byKey(const Key('open-shift-select')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('shift-pin-field')), '1111');
    await tester.enterText(find.byKey(const Key('shift-name-field')), 'Ахмед');
    await tester.tap(find.text('Горячий цех'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shift-clock-in-button')));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, [('1111', 'Ахмед', CookRole.hotChef)]);
    expect(find.byType(ShiftSelectDialog), findsNothing);
    expect(cubit.state.currentCook?.id, 'cook-1111');
    expect(find.text('Ахмед'), findsOneWidget);
    expect(find.text('Выполнено за смену: 0 шт.'), findsOneWidget);
  });

  testWidgets('меню шапки: «Завершить смену» вызывает clock-out', (
    tester,
  ) async {
    final (cubit, repository) = await pumpHeader(
      tester,
      cooks: [buildCook()],
    );
    cubit.selectCook('cook-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cook-shift-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить смену'));
    await tester.pumpAndSettle();

    expect(repository.clockOutCalls, [('cook-1', 'shift-1')]);
    expect(cubit.state.currentCook, isNull);
    expect(find.text('Выбрать смену'), findsOneWidget);
  });
}
