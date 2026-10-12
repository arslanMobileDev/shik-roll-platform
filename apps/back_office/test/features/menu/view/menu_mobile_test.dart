import 'package:back_office/core/utils/money.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_bloc.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_event.dart';
import 'package:back_office/features/menu/data/fake_back_office_repository.dart';
import 'package:back_office/features/menu/data/models/menu_item.dart';
import 'package:back_office/features/menu/view/menu_list_screen.dart';
import 'package:back_office/features/menu/view/widgets/menu_item_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _item = MenuItem(
  id: 'item-1',
  name: 'Филадельфия',
  description: 'Лосось, сыр, огурец',
  categoryName: 'Роллы',
  price: Money(34990),
  isHalal: true,
  isAvailable: false,
);

void main() {
  setUp(() {
    // The bloc reads the staff profile; without the mocks the load never
    // settles and pumpAndSettle spins on the progress indicator.
    SharedPreferences.setMockInitialValues({
      'staff.id': 'staff',
      'staff.name': 'Test',
      'staff.role': 'OWNER',
      'staff.brandId': 'brand',
      'staff.token': 'test-token',
    });
    FlutterSecureStorage.setMockInitialValues({'staff.token': 'test-token'});
  });

  Future<void> pumpTable(
    WidgetTester tester,
    Size size, {
    ValueChanged<MenuItem>? onToggleStopList,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuItemTable(
            items: const [_item],
            pendingItemIds: const {},
            onToggleStopList: onToggleStopList ?? (_) {},
            onEdit: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('390px renders a card, not the table', (tester) async {
    await pumpTable(tester, const Size(390, 844));

    expect(find.text('Доступность'), findsNothing); // desktop column header
    expect(find.byKey(const ValueKey('stopListSwitch-item-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('editItem-item-1')), findsOneWidget);
    expect(find.text('Стоп'), findsOneWidget);
    expect(find.text('Филадельфия'), findsOneWidget);
    expect(find.text('Роллы'), findsOneWidget);
  });

  testWidgets('390px card switch still toggles the stop-list', (tester) async {
    MenuItem? toggled;
    await pumpTable(
      tester,
      const Size(390, 844),
      onToggleStopList: (item) => toggled = item,
    );

    await tester.tap(find.byKey(const ValueKey('stopListSwitch-item-1')));
    await tester.pump();
    expect(toggled?.id, 'item-1');
  });

  testWidgets('1600px keeps the table', (tester) async {
    await pumpTable(tester, const Size(1600, 1000));

    expect(find.text('Доступность'), findsOneWidget);
    expect(find.byKey(const ValueKey('stopListSwitch-item-1')), findsOneWidget);
  });

  // The whole screen at phone width: the header (title + 'Новое блюдо' button)
  // shares one row and would overflow without the Expanded fix.
  testWidgets('390px renders the menu screen without a layout error',
      (tester) async {
    final bloc = MenuCatalogBloc(
      repository: FakeBackOfficeRepository(latency: Duration.zero),
    )..add(const MenuCatalogRequested(branchId: 'branch-center'));
    addTearDown(bloc.close);
    tester.view.physicalSize = const Size(390, 844);
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

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('menuList.addItem')), findsOneWidget);
    expect(find.text('Доступность'), findsNothing);
  });
}
