import 'package:back_office/features/menu/data/models/menu_ref.dart';
import 'package:back_office/features/menu/data/models/menu_category_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;
import 'package:back_office/features/menu/data/back_office_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_bloc.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_event.dart';
import 'package:back_office/features/menu/data/fake_back_office_repository.dart';
import 'package:back_office/features/menu/view/menu_list_screen.dart';
import 'package:back_office/features/menu/view/widgets/category_form_dialog.dart';
import 'package:back_office/features/menu/view/widgets/menu_item_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReferenceRepository extends Mock implements BackOfficeRepository {}

void main() {
  late BackOfficeRepository repository;
  late MenuCatalogBloc bloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'staff.id': 'staff',
      'staff.name': 'Test',
      'staff.role': 'OWNER',
      'staff.brandId': 'brand',
      'staff.token': 'test-token',
    });
    FlutterSecureStorage.setMockInitialValues({'staff.token': 'test-token'});
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

  testWidgets('chips use reference names and UUIDs, not legacy enum names', (
    tester,
  ) async {
    final remote = _ReferenceRepository();
    when(() => remote.fetchMenus(brandId: 'brand')).thenAnswer(
      (_) async => [const MenuRef(id: 'menu', name: 'Меню', brandId: 'brand')],
    );
    when(() => remote.fetchCategories(menuId: 'menu')).thenAnswer(
      (_) async => [
        const MenuCategoryRef(
          id: 'custom-id',
          name: 'Авторские завтраки',
          menuId: 'menu',
        ),
      ],
    );
    when(
      () => remote.fetchMenuItems(branchId: 'branch-center'),
    ).thenAnswer((_) async => []);
    repository = remote;
    await pumpScreen(tester);
    expect(
      find.widgetWithText(ChoiceChip, 'Авторские завтраки'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, 'Роллы'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('categoryFilter.custom-id')));
    await tester.pump();
    expect(bloc.state.categoryFilter, 'custom-id');
    await tester.tap(find.byKey(const ValueKey('categoryFilter.all')));
    await tester.pump();
    expect(bloc.state.categoryFilter, isNull);
  });

  testWidgets('empty categories show only All chip', (tester) async {
    final remote = _ReferenceRepository();
    when(() => remote.fetchMenus(brandId: 'brand')).thenAnswer(
      (_) async => [const MenuRef(id: 'menu', name: 'Меню', brandId: 'brand')],
    );
    when(
      () => remote.fetchCategories(menuId: 'menu'),
    ).thenAnswer((_) async => []);
    when(
      () => remote.fetchMenuItems(branchId: 'branch-center'),
    ).thenAnswer((_) async => []);
    repository = remote;
    await pumpScreen(tester);
    expect(find.byType(ChoiceChip), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Все'), findsOneWidget);
  });

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

    await tester.tap(
      find.byKey(
        const ValueKey('categoryFilter.00000000-0000-4000-8000-000000000102'),
      ),
    );
    await tester.pump();

    expect(find.text('Сет «Халяль Микс»'), findsOneWidget);
    expect(find.text('Филадельфия классик'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('categoryFilter.all')));
    await tester.pump();
    expect(find.text('Филадельфия классик'), findsOneWidget);
  });

  testWidgets('stop-list switch toggles availability with notice', (
    tester,
  ) async {
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
    expect(
      find.widgetWithText(TextFormField, 'Филадельфия классик'),
      findsOneWidget,
    );
  });

  testWidgets('creates a category from the filters row', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('menuList.addCategory')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryFormDialog), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('categoryForm.name')),
      'Авторские роллы',
    );
    await tester.enterText(
      find.byKey(const ValueKey('categoryForm.description')),
      'Только для постоянных гостей',
    );
    await tester.tap(find.byKey(const ValueKey('categoryForm.save')));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryFormDialog), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Авторские роллы'), findsOneWidget);
    expect(bloc.state.categories.last.name, 'Авторские роллы');
    expect(bloc.state.categories.last.isActive, isTrue);
    expect(find.textContaining('создана'), findsOneWidget);
  });

  testWidgets('pencil renames a category and hides it from the menu', (
    tester,
  ) async {
    await pumpScreen(tester);
    final rollsId = FakeBackOfficeRepository.categoryRolls.id;

    await tester.tap(find.byKey(ValueKey('categoryEdit.$rollsId')));
    await tester.pumpAndSettle();
    expect(find.text('Редактировать категорию'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Роллы'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('categoryForm.name')),
      'Роллы и суши',
    );
    await tester.tap(find.byKey(const ValueKey('categoryForm.active')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('categoryForm.save')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Роллы и суши'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Роллы'), findsNothing);
    // Hidden, not deleted: the chip stays so it can be switched back on.
    expect(
      bloc.state.categories.firstWhere((e) => e.id == rollsId).isActive,
      isFalse,
    );
    expect(find.textContaining('скрыта'), findsOneWidget);
  });

  testWidgets('dish form creates a category from the dropdown and selects it', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('menuList.addItem')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('menuItemForm.category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Создать новую категорию').last);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryFormDialog), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('categoryForm.name')),
      'Завтраки',
    );
    await tester.tap(find.byKey(const ValueKey('categoryForm.save')));
    await tester.pumpAndSettle();

    // The dish form survived the detour and points at the new category.
    expect(find.byType(MenuItemFormDialog), findsOneWidget);
    expect(bloc.state.categories.last.name, 'Завтраки');
    expect(
      tester
          .state<FormFieldState<String>>(
            find.byKey(const ValueKey('menuItemForm.category')),
          )
          .value,
      bloc.state.categories.last.id,
    );
  });

  testWidgets('cancelling category creation leaves the dish selection alone', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('menuList.addItem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menuItemForm.category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сеты').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('menuItemForm.category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Создать новую категорию').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Отмена').last);
    await tester.pumpAndSettle();

    // The "+ create" entry must not stay behind as the selected option.
    expect(
      tester
          .state<FormFieldState<String>>(
            find.byKey(const ValueKey('menuItemForm.category')),
          )
          .value,
      FakeBackOfficeRepository.categorySets.id,
    );
  });
}
