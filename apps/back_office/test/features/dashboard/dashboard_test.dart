import 'dart:async';
import 'package:back_office/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:back_office/features/dashboard/bloc/dashboard_state.dart';
import 'package:back_office/features/dashboard/data/dashboard_repository.dart';
import 'package:back_office/features/dashboard/data/fake_dashboard_repository.dart';
import 'package:back_office/features/dashboard/data/models/revenue_summary.dart';
import 'package:back_office/features/dashboard/view/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final class ControlledRepository implements DashboardRepository {
  final demo = FakeDashboardRepository(now: () => DateTime.utc(2026, 9, 16));
  final old = Completer<void>();
  bool fail = false;
  final branches = <String>[];
  @override
  Future<RevenueSummary> fetchRevenue({
    required String branchId,
    required DashboardPeriod period,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    branches.add(branchId);
    if (branchId == 'old') await old.future;
    if (fail) throw StateError('offline');
    return demo.fetchRevenue(
      branchId: branchId,
      period: period,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  test(
    'loads four cards and selected period from the requested branch',
    () async {
      final repository = ControlledRepository();
      final cubit = DashboardCubit(repository: repository);
      await cubit.load('branch');
      expect(cubit.state.status, DashboardStatus.loaded);
      expect(cubit.state.cards.length, 4);
      expect(repository.branches, everyElement('branch'));
      await cubit.select(
        DashboardPeriod.custom,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 3),
      );
      expect(cubit.state.revenue!.byDay.length, 3);
      await cubit.close();
    },
  );
  test('late responses cannot overwrite the newly selected branch', () async {
    final repository = ControlledRepository();
    final cubit = DashboardCubit(repository: repository);
    final first = cubit.load('old');
    await cubit.load('new');
    repository.old.complete();
    await first;
    expect(cubit.state.branchId, 'new');
    expect(cubit.state.status, DashboardStatus.loaded);
    await cubit.close();
  });
  test('error can be retried without losing selected period', () async {
    final repository = ControlledRepository()..fail = true;
    final cubit = DashboardCubit(repository: repository);
    await cubit.load('branch', period: DashboardPeriod.month);
    expect(cubit.state.status, DashboardStatus.error);
    repository.fail = false;
    await cubit.refresh();
    expect(cubit.state.period, DashboardPeriod.month);
    expect(cubit.state.status, DashboardStatus.loaded);
    await cubit.close();
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'dashboard cards and tables render without overflow at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = DashboardCubit(
          repository: FakeDashboardRepository(
            now: () => DateTime.utc(2026, 9, 16),
          ),
        );
        await cubit.load('branch');
        addTearDown(cubit.close);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: DashboardScreen()),
            ),
          ),
        );
        expect(find.text('Выручка'), findsWidgets);
        expect(find.text('По дням'), findsOneWidget);
        expect(find.text('Топ-5 блюд'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final cards = tester.widgetList<Card>(find.byType(Card)).toList();
        expect(cards.length, 6);
      },
    );
  }
}
