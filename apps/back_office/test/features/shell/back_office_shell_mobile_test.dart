import 'package:back_office/core/widgets/halal_badge.dart';
import 'package:back_office/features/shell/bloc/branch_cubit.dart';
import 'package:back_office/features/shell/view/back_office_shell.dart';
import 'package:back_office/features/shell/view/branch_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<BranchCubit>(
          create: (_) => BranchCubit(),
          child: BackOfficeShell(
            sectionBuilder: (section) =>
                Center(child: Text('screen:${section.name}')),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('390x844 (phone)', () {
    testWidgets('hides the sidebar and shows the burger', (tester) async {
      await pumpShell(tester, const Size(390, 844));

      expect(find.byKey(const ValueKey('topbar.menu')), findsOneWidget);
      expect(find.byType(BranchSelector), findsNothing);
      expect(find.text('Стоп-листы'), findsNothing);
      expect(find.byType(HalalBadge), findsOneWidget);
    });

    testWidgets('burger opens the drawer and a tap navigates + closes it',
        (tester) async {
      await pumpShell(tester, const Size(390, 844));

      await tester.tap(find.byKey(const ValueKey('topbar.menu')));
      await tester.pumpAndSettle();
      expect(find.text('Стоп-листы'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sidebar.stopLists')));
      await tester.pumpAndSettle();

      expect(find.text('screen:stopLists'), findsOneWidget);
      // Drawer dismissed → its contents are gone again (only the top bar
      // still carries the label).
      expect(find.text('Стоп-листы'), findsOneWidget);
    });
  });

  testWidgets('1280x900 (desktop) keeps the pinned sidebar', (tester) async {
    await pumpShell(tester, const Size(1280, 900));

    expect(find.byKey(const ValueKey('topbar.menu')), findsNothing);
    expect(find.byType(BranchSelector), findsOneWidget);
    expect(find.text('Стоп-листы'), findsOneWidget);
  });
}
