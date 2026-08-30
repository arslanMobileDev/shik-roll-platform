import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/features/catalog/view/widgets/category_sortable_list.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  final categories = [
    testCategory(id: 'cat-rolls', name: 'Роллы', sortOrder: 0),
    testCategory(id: 'cat-sets', name: 'Сеты', sortOrder: 1, itemCount: 2),
  ];

  group('CategorySortableList (selection mode)', () {
    testWidgets('renders "all" tile and every category with item counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          CategorySortableList(
            categories: categories,
            selectedCategoryId: null,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Роллы'), findsOneWidget);
      expect(find.text('Сеты'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('reports category taps and null for the "all" tile', (
      tester,
    ) async {
      final selected = <String?>[];
      await tester.pumpWidget(
        wrap(
          CategorySortableList(
            categories: categories,
            selectedCategoryId: null,
            onSelected: selected.add,
          ),
        ),
      );

      await tester.tap(find.text('Роллы'));
      await tester.tap(find.text('Все'));
      await tester.pump();

      expect(selected, ['cat-rolls', null]);
    });

    testWidgets('highlights the selected category', (tester) async {
      await tester.pumpWidget(
        wrap(
          CategorySortableList(
            categories: categories,
            selectedCategoryId: 'cat-sets',
            onSelected: (_) {},
          ),
        ),
      );

      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      final selectedTile = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Сеты'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(selectedTile.color, theme.colorScheme.primaryContainer);
    });
  });

  group('CategorySortableList (reorder mode)', () {
    testWidgets('reports the new id order after a drag reorder', (
      tester,
    ) async {
      final orders = <List<String>>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 400,
            child: CategorySortableList(
              categories: categories,
              selectedCategoryId: null,
              onSelected: (_) {},
              onReorder: orders.add,
            ),
          ),
        ),
      );

      // Drag "Роллы" below "Сеты".
      await tester.drag(find.text('Роллы'), const Offset(0, 120));
      await tester.pumpAndSettle();

      expect(orders, isNotEmpty);
      expect(orders.last, ['cat-sets', 'cat-rolls']);
    });
  });
}
