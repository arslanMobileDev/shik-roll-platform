import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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
CourierRecord deletedCourier({
  String id = 'gone',
  String? phone = '+79280000001',
  Duration ago = const Duration(days: 1),
}) => CourierRecord(
  id: id,
  name: 'Ушедший',
  phone: phone,
  branchId: branch,
  isActive: false,
  isAvailable: false,
  createdAt: DateTime(2026),
  deletedAt: DateTime.now().subtract(ago),
);
Future<void> openDeleted(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('couriers.filter.deleted')));
  await tester.pumpAndSettle();
}

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

  // A self-deleted courier keeps its row (it anchors the order history) but
  // loses its number, so /staff/couriers answers "phone": null. The cast in
  // CourierRecord.fromJson used to be unconditional, and a single deleted
  // courier took the whole list down to "Не удалось выполнить запрос".
  group('self-deleted courier (phone: null)', () {
    Map<String, dynamic> json({Object? phone}) => {
      'id': 'courier',
      'name': 'Удалённый курьер',
      'phone': phone,
      'branchId': branch,
      'isActive': false,
      'isAvailable': false,
      'createdAt': '2026-10-14T12:00:00.000Z',
    };

    test('parses a null phone instead of throwing', () {
      expect(CourierRecord.fromJson(json()).phone, isNull);
    });

    testWidgets('the list still renders, with a placeholder contact', (
      tester,
    ) async {
      await render(tester, rows: [CourierRecord.fromJson(json())]);

      expect(find.text('Удалённый курьер'), findsOneWidget);
      expect(find.text('без номера'), findsOneWidget);
    });

    testWidgets('editing it can be saved without re-entering a phone', (
      tester,
    ) async {
      final cubit = await render(
        tester,
        rows: [CourierRecord.fromJson(json())],
      );
      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Введите российский телефон'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(cubit.state.rows, hasLength(1));
    });
  });

  group('Удалённые', () {
    testWidgets('the tab lists the self-deleted and brings one back', (
      tester,
    ) async {
      final gone = deletedCourier();
      final cubit = await render(tester, rows: [courier(), gone]);
      expect(find.text('Ушедший'), findsNothing);

      await openDeleted(tester);
      expect(find.text('Ушедший'), findsOneWidget);
      expect(find.text('Иван'), findsNothing);
      expect(find.byKey(const Key('new-courier')), findsNothing);
      final deadline = DateFormat(
        'dd.MM.yyyy',
      ).format(gone.deletedAt!.add(const Duration(days: 7)));
      expect(find.text('Восстановить можно до $deadline'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('restore-gone')));
      await tester.pumpAndSettle();
      expect(find.text('Удалённых курьеров нет'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('couriers.filter.active')));
      await tester.pumpAndSettle();
      expect(cubit.state.rows, hasLength(2));
      final live = cubit.state.rows.firstWhere((r) => r.name == 'Ушедший');
      expect(live.isActive, isTrue);
      expect(live.deletedAt, isNull);
      expect(find.text('Ушедший'), findsOneWidget);
    });

    testWidgets('a legacy row with no number cannot be restored', (
      tester,
    ) async {
      await render(tester, rows: [deletedCourier(phone: null)]);

      await openDeleted(tester);
      expect(find.text('Ушедший'), findsOneWidget);
      expect(find.text('без номера'), findsOneWidget);
      expect(find.byKey(const ValueKey('restore-gone')), findsNothing);
    });

    testWidgets('an expired window says so instead of offering restore', (
      tester,
    ) async {
      await render(
        tester,
        rows: [deletedCourier(ago: const Duration(days: 8))],
      );

      await openDeleted(tester);
      expect(find.text('Срок восстановления истёк'), findsOneWidget);
      expect(find.byKey(const ValueKey('restore-gone')), findsNothing);
    });

    testWidgets('a link the backend refuses says why and keeps the row', (
      tester,
    ) async {
      // The live courier holds the number the deleted row still carries — the
      // one state the restore cannot produce, and the only 409 there is.
      await render(
        tester,
        rows: [
          courier(),
          deletedCourier(phone: '+79280000000'),
        ],
      );

      await openDeleted(tester);
      await tester.tap(find.byKey(const ValueKey('restore-gone')));
      await tester.pumpAndSettle();
      expect(
        find.text('Этот телефон уже занят другим курьером.'),
        findsOneWidget,
      );
      expect(find.text('Ушедший'), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Ушедший'), findsOneWidget);
      expect(find.text('Иван'), findsNothing);
    });
  });
}
