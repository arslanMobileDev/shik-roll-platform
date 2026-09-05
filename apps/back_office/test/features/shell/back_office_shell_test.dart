import 'package:back_office/core/widgets/halal_badge.dart';
import 'package:back_office/features/shell/bloc/branch_cubit.dart';
import 'package:back_office/features/shell/view/back_office_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, {Size size = const Size(1600, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<BranchCubit>(
          create: (_) => BranchCubit(),
          child: BackOfficeShell(
            sectionBuilder: (section) => Center(child: Text('screen:${section.name}')),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders sidebar, top bar, halal badge and active branch',
      (tester) async {
    await pumpShell(tester);

    expect(find.text('screen:menu'), findsOneWidget);
    expect(find.text('Меню и блюда'), findsWidgets); // sidebar + top bar
    expect(find.text('Стоп-листы'), findsOneWidget);
    expect(find.text('Настройки точки'), findsOneWidget);
    expect(find.byType(HalalBadge), findsOneWidget);
    expect(find.text('SHIK ROLL · Центр'), findsWidgets); // selector + sidebar footer
  });

  testWidgets('switches sections from the sidebar', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const ValueKey('sidebar.stopLists')));
    await tester.pumpAndSettle();
    expect(find.text('screen:stopLists'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidebar.branchSettings')));
    await tester.pumpAndSettle();
    expect(find.text('screen:branchSettings'), findsOneWidget);
  });

  testWidgets('collapses sidebar below 1280px', (tester) async {
    await pumpShell(tester, size: const Size(1100, 900));

    // Labels collapse into icon-only rail with tooltips.
    expect(find.text('Стоп-листы'), findsNothing);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);
  });
}
