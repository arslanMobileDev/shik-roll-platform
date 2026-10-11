import 'package:back_office/core/utils/money.dart';
import 'package:back_office/features/menu/data/models/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// The API (API-706) takes `categoryId` and `basePrice`; the client used to
/// post `category` (a local enum name) and `price`, which the Nest whitelist
/// silently dropped while still answering 200 — "saved" without saving.
void main() {
  group('MenuItemDraft.toJson', () {
    test('uses the field names the API accepts', () {
      const draft = MenuItemDraft(
        name: 'Шик бургер с говядиной',
        description: 'Мраморная говядина',
        categoryId: 'cat-burger',
        price: Money(34900),
        isHalal: true,
      );

      final json = draft.toJson();

      expect(json['categoryId'], 'cat-burger');
      expect(json['name'], 'Шик бургер с говядиной');
      expect(json['basePrice'], 349.0);
      expect(json.containsKey('category'), isFalse, reason: 'the API ignores it');
      expect(json.containsKey('price'), isFalse, reason: 'the API ignores it');
      // The PATCH DTO accepts isHalal (it resolves the HALAL tag server-side);
      // a client that sends a raw certificationTagIds UUID would be tied to one
      // database, so the payload keeps the boolean.
      expect(json['isHalal'], isTrue);
      expect(json.containsKey('certificationTagIds'), isFalse);
    });
  });

  group('MenuItem.fromJson', () {
    test('reads the category id the filter chips compare against', () {
      final item = MenuItem.fromJson(const {
        'id': 'i1',
        'name': 'Шик бургер',
        'category': {'id': 'cat-burger', 'name': 'Бургеры', 'menuId': 'm1'},
        'price': {'effective': 349.0},
      });

      expect(item.categoryId, 'cat-burger');
      expect(item.categoryName, 'Бургеры');
    });
  });
}
