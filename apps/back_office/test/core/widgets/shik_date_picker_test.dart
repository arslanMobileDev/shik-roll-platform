import 'package:back_office/core/widgets/shik_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts a button that opens [open] and records its result in [result].
Future<void> _host(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context) open,
  void Function(Object? value) result,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => result(await open(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final first = DateTime(2026, 1, 1);
  final last = DateTime(2026, 12, 31);

  group('showShikDatePicker', () {
    testWidgets('opens on the month grid, in Russian', (tester) async {
      await _host(
        tester,
        (c) => showShikDatePicker(
          c,
          initialDate: DateTime(2026, 10, 11),
          firstDate: first,
          lastDate: last,
        ),
        (_) {},
      );

      expect(find.text('Выберите дату'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      for (final month in const [
        'Январь',
        'Февраль',
        'Март',
        'Апрель',
        'Май',
        'Июнь',
        'Июль',
        'Август',
        'Сентябрь',
        'Октябрь',
        'Ноябрь',
        'Декабрь',
      ]) {
        expect(find.text(month), findsOneWidget, reason: month);
      }
      expect(find.text('Select date'), findsNothing);
      expect(find.text('Отмена'), findsOneWidget);
    });

    testWidgets('month tap opens the day grid, Monday first', (tester) async {
      await _host(
        tester,
        (c) => showShikDatePicker(
          c,
          initialDate: DateTime(2026, 10, 11),
          firstDate: first,
          lastDate: last,
        ),
        (_) {},
      );

      await tester.tap(find.byKey(const ValueKey('shik.datePicker.month.10')));
      await tester.pumpAndSettle();

      expect(find.text('Октябрь 2026'), findsOneWidget);
      expect(find.text('Пн'), findsOneWidget);
      expect(find.text('Вс'), findsOneWidget);
      // 1 Oct 2026 is a Thursday, so the grid leads with three blanks and
      // every day 1..31 is present exactly once.
      for (var day = 1; day <= 31; day++) {
        final key = 'shik.datePicker.day.2026-10-${day.toString().padLeft(2, '0')}';
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: 'day $day');
      }
    });

    testWidgets('day tap returns the date', (tester) async {
      Object? picked;
      await _host(
        tester,
        (c) => showShikDatePicker(
          c,
          initialDate: DateTime(2026, 10, 11),
          firstDate: first,
          lastDate: last,
        ),
        (value) => picked = value,
      );

      await tester.tap(find.byKey(const ValueKey('shik.datePicker.month.10')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shik.datePicker.day.2026-10-21')),
      );
      await tester.pumpAndSettle();

      expect(picked, DateTime(2026, 10, 21));
    });

    testWidgets('cancel returns null', (tester) async {
      Object? picked = 'sentinel';
      await _host(
        tester,
        (c) => showShikDatePicker(
          c,
          initialDate: DateTime(2026, 10, 11),
          firstDate: first,
          lastDate: last,
        ),
        (value) => picked = value,
      );

      await tester.tap(find.byKey(const ValueKey('shik.datePicker.cancel')));
      await tester.pumpAndSettle();

      expect(picked, isNull);
    });

    testWidgets('days outside the allowed range are disabled', (tester) async {
      await _host(
        tester,
        (c) => showShikDatePicker(
          c,
          initialDate: DateTime(2026, 10, 11),
          firstDate: DateTime(2026, 10, 5),
          lastDate: DateTime(2026, 10, 20),
        ),
        (_) {},
      );

      await tester.tap(find.byKey(const ValueKey('shik.datePicker.month.10')));
      await tester.pumpAndSettle();

      final before = tester.widget<InkWell>(
        find.byKey(const ValueKey('shik.datePicker.day.2026-10-04')),
      );
      final inside = tester.widget<InkWell>(
        find.byKey(const ValueKey('shik.datePicker.day.2026-10-15')),
      );
      expect(before.onTap, isNull);
      expect(inside.onTap, isNotNull);
    });
  });

  group('showShikDateRangePicker', () {
    testWidgets('start -> end -> apply returns the range', (tester) async {
      Object? picked;
      await _host(
        tester,
        (c) => showShikDateRangePicker(
          c,
          firstDate: first,
          lastDate: last,
        ),
        (value) => picked = value,
      );

      expect(find.text('Начало периода'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shik.datePicker.month.6')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shik.datePicker.day.2026-06-03')),
      );
      await tester.pumpAndSettle();

      // Still open, now asking for the end.
      expect(find.text('Конец периода'), findsOneWidget);
      expect(find.text('начало: 03.06.2026'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('shik.datePicker.day.2026-06-17')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shik.datePicker.apply')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shik.datePicker.apply')));
      await tester.pumpAndSettle();

      expect(
        picked,
        DateTimeRange(
          start: DateTime(2026, 6, 3),
          end: DateTime(2026, 6, 17),
        ),
      );
    });

    testWidgets('days before the chosen start are disabled', (tester) async {
      await _host(
        tester,
        (c) => showShikDateRangePicker(c, firstDate: first, lastDate: last),
        (_) {},
      );

      await tester.tap(find.byKey(const ValueKey('shik.datePicker.month.6')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shik.datePicker.day.2026-06-10')),
      );
      await tester.pumpAndSettle();

      final earlier = tester.widget<InkWell>(
        find.byKey(const ValueKey('shik.datePicker.day.2026-06-09')),
      );
      final sameDay = tester.widget<InkWell>(
        find.byKey(const ValueKey('shik.datePicker.day.2026-06-10')),
      );
      expect(earlier.onTap, isNull);
      expect(sameDay.onTap, isNotNull, reason: 'one-day ranges stay allowed');
    });
  });
}
