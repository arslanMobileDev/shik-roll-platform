import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/features/catalog/data/catalog_models.dart';
import 'package:pos/features/catalog/view/widgets/modifier_tree_selector.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('ModifierTreeSelector', () {
    testWidgets('renders all groups and options in sort order', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ModifierTreeSelector(
            groups: [testModifierGroup()],
            selection: const {},
            onToggle: (_, _, _) {},
          ),
        ),
      );

      expect(find.text('Соус'), findsOneWidget);
      expect(find.text('Спайси'), findsOneWidget);
      expect(find.text('Унаги'), findsOneWidget);
      expect(find.text('Соевый'), findsOneWidget);
    });

    testWidgets('shows kind icons for WEIGHT/PORTION/ADDON/SAUCE groups', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ModifierTreeSelector(
            groups: [
              testModifierGroup(id: 'g1', name: 'Вес'),
              testModifierGroup(id: 'g2', name: 'Порция'),
              testModifierGroup(id: 'g3', name: 'Добавки'),
              testModifierGroup(id: 'g4', name: 'Соус'),
            ],
            kinds: const {
              'g1': ModifierKind.weight,
              'g2': ModifierKind.portion,
              'g3': ModifierKind.addon,
              'g4': ModifierKind.sauce,
            },
            selection: const {},
            onToggle: (_, _, _) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.scale_outlined), findsOneWidget);
      expect(find.byIcon(Icons.dinner_dining_outlined), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('reports option toggle with group and option ids', (
      tester,
    ) async {
      final toggles = <(String, String, bool)>[];
      await tester.pumpWidget(
        wrap(
          ModifierTreeSelector(
            groups: [testModifierGroup()],
            selection: const {},
            onToggle: (g, o, selected) => toggles.add((g, o, selected)),
          ),
        ),
      );

      await tester.tap(find.text('Спайси'));
      await tester.pump();

      expect(toggles, [('mg-sauce', 'mi-spicy', true)]);
    });

    testWidgets('single-choice groups render radio indicators', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ModifierTreeSelector(
            groups: [
              testModifierGroup(
                selectionType: ModifierSelectionType.single,
              ),
            ],
            selection: const {
              'mg-sauce': {'mi-spicy'},
            },
            onToggle: (_, _, _) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_off), findsNWidgets(2));
      expect(find.byIcon(Icons.check_box), findsNothing);
    });

    testWidgets('multiple-choice groups render checkbox indicators', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ModifierTreeSelector(
            groups: [testModifierGroup()],
            selection: const {
              'mg-sauce': {'mi-spicy'},
            },
            onToggle: (_, _, _) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
    });

    testWidgets(
      'disables unselected options when maxSelected is reached',
      (tester) async {
        var toggleCount = 0;
        await tester.pumpWidget(
          wrap(
            ModifierTreeSelector(
              groups: [testModifierGroup(maxSelected: 2)],
              selection: const {
                'mg-sauce': {'mi-spicy', 'mi-unagi'},
              },
              onToggle: (_, _, _) => toggleCount++,
            ),
          ),
        );

        // Selected options stay tappable (to deselect).
        await tester.tap(find.text('Спайси'));
        await tester.pump();
        expect(toggleCount, 1);

        // The third option is disabled: tap is swallowed by the widget.
        await tester.tap(find.text('Соевый'));
        await tester.pump();
        expect(toggleCount, 1);
      },
    );

    testWidgets('marks required groups', (tester) async {
      await tester.pumpWidget(
        wrap(
          ModifierTreeSelector(
            groups: [testModifierGroup(isRequired: true, minSelected: 1)],
            selection: const {},
            onToggle: (_, _, _) {},
          ),
        ),
      );

      expect(find.text('обязательно'), findsOneWidget);
    });

    testWidgets('shows surcharge for priced options only', (tester) async {
      await tester.pumpWidget(
        wrap(
          ModifierTreeSelector(
            groups: [testModifierGroup()],
            selection: const {},
            onToggle: (_, _, _) {},
          ),
        ),
      );

      // Spicy and Unagi cost 40 ₽; soy sauce is free.
      expect(find.textContaining('+40,00'), findsNWidgets(2));
    });
  });
}
