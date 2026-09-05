import 'package:back_office/core/utils/money.dart';
import 'package:back_office/features/menu/data/models/menu_item.dart';
import 'package:back_office/features/menu/view/widgets/menu_item_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _existing = MenuItem(
  id: 'r1',
  name: 'Филадельфия',
  description: 'Лосось, сыр',
  category: MenuCategory.rolls,
  price: Money(44900),
  isHalal: true,
  isAvailable: true,
);

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    MenuItem? initial,
    required void Function(MenuItemDraft?) onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                onResult(
                  await MenuItemFormDialog.show(context, initial: initial),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('validates required name and price on save', (tester) async {
    var called = false;
    await openDialog(tester, onResult: (_) => called = true);

    await tester.tap(find.byKey(const ValueKey('menuItemForm.save')));
    await tester.pump();

    expect(find.text('Укажите название'), findsOneWidget);
    expect(find.text('Некорректная цена'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('rejects malformed price', (tester) async {
    var called = false;
    await openDialog(tester, onResult: (_) => called = true);

    await tester.enterText(
      find.byKey(const ValueKey('menuItemForm.name')),
      'Тест',
    );
    await tester.enterText(
      find.byKey(const ValueKey('menuItemForm.price')),
      '12.3.4',
    );
    await tester.tap(find.byKey(const ValueKey('menuItemForm.save')));
    await tester.pump();

    expect(find.text('Некорректная цена'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('creates draft with parsed kopecks and chosen category',
      (tester) async {
    MenuItemDraft? result;
    await openDialog(tester, onResult: (draft) => result = draft);

    await tester.enterText(
      find.byKey(const ValueKey('menuItemForm.name')),
      'Сет «Тестовый»',
    );
    await tester.enterText(
      find.byKey(const ValueKey('menuItemForm.price')),
      '349.9',
    );

    await tester.tap(find.byKey(const ValueKey('menuItemForm.category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(MenuCategory.sets.label).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('menuItemForm.save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Сет «Тестовый»');
    expect(result!.price, const Money(34990));
    expect(result!.category, MenuCategory.sets);
    expect(result!.isHalal, isTrue);
    expect(result!.imageUrl, isNull);
  });

  testWidgets('halal switch toggles draft flag', (tester) async {
    MenuItemDraft? result;
    await openDialog(tester, onResult: (draft) => result = draft);

    await tester.enterText(
      find.byKey(const ValueKey('menuItemForm.name')),
      'Ролл',
    );
    await tester.enterText(
      find.byKey(const ValueKey('menuItemForm.price')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('menuItemForm.halal')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('menuItemForm.save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isHalal, isFalse);
  });

  testWidgets('edit mode prefills fields and returns updated draft',
      (tester) async {
    MenuItemDraft? result;
    await openDialog(
      tester,
      initial: _existing,
      onResult: (draft) => result = draft,
    );

    expect(find.text('Редактировать блюдо'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Филадельфия'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '449.00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('menuItemForm.price')),
      '500',
    );
    await tester.tap(find.byKey(const ValueKey('menuItemForm.save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Филадельфия');
    expect(result!.price, const Money(50000));
  });

  testWidgets('cancel pops without a draft', (tester) async {
    var called = false;
    MenuItemDraft? result;
    await openDialog(
      tester,
      onResult: (draft) {
        called = true;
        result = draft;
      },
    );

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });
}
