import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:back_office/core/theme/app_theme.dart';
import 'package:back_office/features/couriers/bloc/couriers_cubit.dart';
import 'package:back_office/features/couriers/data/couriers_repository.dart';
import 'package:back_office/features/couriers/data/fake_couriers_repository.dart';
import 'package:back_office/features/couriers/view/couriers_screen.dart';

const branch = 'branch';
CourierRecord courier() => CourierRecord(
  id: 'courier',
  name: 'Иван',
  phone: '+79280000000',
  branchId: branch,
  isActive: true,
  isAvailable: false,
  createdAt: DateTime(2026),
);
Future<CouriersCubit> render(
  WidgetTester tester, {
  List<CourierRecord> rows = const [],
}) async {
  final cubit = CouriersCubit(FakeCouriersRepository(initial: rows));
  addTearDown(cubit.close);
  await cubit.load(branch);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: CouriersScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('empty list placeholder', (tester) async {
    await render(tester);
    expect(find.text('Курьеры ещё не добавлены'), findsOneWidget);
  });
  testWidgets('cards show account status separately from availability', (
    tester,
  ) async {
    await render(tester, rows: [courier()]);
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('+79280000000'), findsOneWidget);
    expect(find.text('Активен · Занят'), findsOneWidget);
  });
  testWidgets('creation validates fields, saves and closes dialog', (
    tester,
  ) async {
    final cubit = await render(tester);
    await tester.tap(find.byKey(const Key('new-courier')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-courier')));
    await tester.pumpAndSettle();
    expect(find.text('Введите имя'), findsOneWidget);
    expect(find.text('Введите российский телефон'), findsOneWidget);
    expect(find.text('PIN: 4–8 цифр'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('courier-name')),
      'Новый Курьер',
    );
    await tester.enterText(
      find.byKey(const Key('courier-phone')),
      '9280000000',
    );
    await tester.enterText(find.byKey(const Key('courier-pin')), '1234');
    await tester.tap(find.byKey(const Key('save-courier')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Новый Курьер'), findsOneWidget);
    expect(cubit.state.rows.single.phone, '+79280000000');
  });
  testWidgets('blocking does not change availability and can be reversed', (
    tester,
  ) async {
    final cubit = await render(tester, rows: [courier()]);
    await tester.tap(find.byKey(const ValueKey('toggle-courier')));
    await tester.pumpAndSettle();
    expect(cubit.state.rows.single.isActive, isFalse);
    expect(cubit.state.rows.single.isAvailable, isFalse);
    expect(find.text('Заблокирован · Занят'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-courier')));
    await tester.pumpAndSettle();
    expect(cubit.state.rows.single.isActive, isTrue);
  });
  testWidgets('editing keeps phone read-only and allows an empty new PIN', (
    tester,
  ) async {
    final cubit = await render(tester, rows: [courier()]);
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('courier-phone')))
          .initialValue,
      '+79280000000',
    );
    await tester.enterText(find.byKey(const Key('courier-name')), 'Другое имя');
    await tester.tap(find.byKey(const Key('save-courier')));
    await tester.pumpAndSettle();
    expect(cubit.state.rows.single.name, 'Другое имя');
    expect(cubit.state.rows.single.phone, '+79280000000');
    expect(find.byType(AlertDialog), findsNothing);
  });
}
