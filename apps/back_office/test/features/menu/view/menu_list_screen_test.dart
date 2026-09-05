import 'package:back_office/features/menu/bloc/menu_catalog_bloc.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_event.dart';
import 'package:back_office/features/menu/data/fake_back_office_repository.dart';
import 'package:back_office/features/menu/view/menu_list_screen.dart';
import 'package:back_office/features/menu/view/widgets/menu_item_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeBackOfficeRepository repository;
  late MenuCatalogBloc bloc;

  setUp(() {
    repository = FakeBackOfficeRepository(latency: Duration.zero);
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Create the bloc and dispatch inside the test body so the fake
    // repository's Future.delayed lives in the test's FakeAsync zone.
    bloc = MenuCatalogBloc(repository: repository)
      ..add(const MenuCatalogRequested(branchId: 'branch-center'));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MenuCatalogBloc>.value(
          value: bloc,
          child: const Scaffold(body: MenuListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders catalog table with items after load', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Меню и блюда'), findsOneWidget);
    expect(find.text('Филадельфия классик'), findsOneWidget);
    expect(find.text('ШИК бургер'), findsOneWidget);
    // demo-6 is seeded on the stop-list of branch-center.
    expect(find.text('Стоп'), findsOneWidget);
    // Price column renders formatted RUB values.
    expect(find.textContaining('449,00'), findsOneWidget);
  });

  testWidgets('filters items by category', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('categoryFilter.sets')));
    await tester.pump();

    expect(find.text('Сет «Халяль Микс»'), findsOneWidget);
    expect(find.text('Филадельфия классик'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('categoryFilter.all')));
    await tester.pump();
    expect(find.text('Филадельфия классик'), findsOneWidget);
  });

  testWidgets('stop-list switch toggles availability with notice',
      (tester) async {
    await pumpScreen(tester);

    expect(
      bloc.state.items.firstWhere((e) => e.id == 'demo-1').isAvailable,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('stopListSwitch-demo-1')));
    await tester.pumpAndSettle();

    expect(
      bloc.state.items.firstWhere((e) => e.id == 'demo-1').isAvailable,
      isFalse,
    );
    expect(find.textContaining('стоп-лист'), findsOneWidget);
    // Notice is consumed after being shown.
    expect(bloc.state.notice, isNull);

    // Branch isolation: north branch keeps the item available.
    // runAsync: repo futures use timers that FakeAsync would never fire.
    final north = await tester.runAsync(
      () => repository.fetchMenuItems(branchId: 'branch-north'),
    );
    expect(north!.firstWhere((e) => e.id == 'demo-1').isAvailable, isTrue);
  });

  testWidgets('edit button opens prefilled form dialog', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('editItem-demo-1')));
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemFormDialog), findsOneWidget);
    expect(find.text('Редактировать блюдо'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Филадельфия классик'),
        findsOneWidget);
  });
}
