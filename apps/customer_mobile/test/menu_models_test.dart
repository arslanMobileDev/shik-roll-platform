import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'menu_item_json_fixture.dart';

void main() {
  group('MenuItem.fromJson', () {
    test('parses imageUrl when the API sends one', () {
      final item = MenuItem.fromJson(
        menuItemJson(
          imageUrl: 'https://api.shik-roll.ru/uploads/menu/roll.webp',
        ),
      );

      expect(item.imageUrl, 'https://api.shik-roll.ru/uploads/menu/roll.webp');
    });

    test('keeps imageUrl null when the field is absent', () {
      expect(MenuItem.fromJson(menuItemJson()).imageUrl, isNull);
    });

    test('keeps imageUrl null when the API sends null', () {
      expect(MenuItem.fromJson(menuItemJson(imageUrl: null)).imageUrl, isNull);
    });

    test('parses the base fields the menu grid reads', () {
      final item = MenuItem.fromJson(menuItemJson());

      expect(item.id, 'item-1');
      expect(item.name, 'Филадельфия');
      expect(item.category.name, 'Роллы');
      expect(item.price, const Money.kopecks(39000));
    });
  });
}
