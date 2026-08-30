import 'package:pos/core/utils/money.dart';
import 'package:pos/features/catalog/data/catalog_models.dart';

/// Shared builders for catalog fixtures used across widget and bloc tests.

Category testCategory({
  String id = 'cat-rolls',
  String name = 'Роллы',
  int sortOrder = 0,
  int itemCount = 3,
  bool isActive = true,
}) {
  return Category(
    id: id,
    brandId: 'brand-shik-roll',
    menuId: 'menu-main',
    name: name,
    sortOrder: sortOrder,
    isActive: isActive,
    itemCount: itemCount,
  );
}

ModifierItem testModifierOption({
  String id = 'mi-spicy',
  String name = 'Спайси',
  Money price = const Money.kopecks(4000),
  int sortOrder = 0,
}) {
  return ModifierItem(
    id: id,
    name: name,
    price: price,
    currency: 'RUB',
    sortOrder: sortOrder,
  );
}

ModifierGroup testModifierGroup({
  String id = 'mg-sauce',
  String name = 'Соус',
  ModifierSelectionType selectionType = ModifierSelectionType.multiple,
  int minSelected = 0,
  int? maxSelected = 2,
  bool isRequired = false,
  List<ModifierItem>? items,
}) {
  return ModifierGroup(
    id: id,
    name: name,
    selectionType: selectionType,
    minSelected: minSelected,
    maxSelected: maxSelected,
    isRequired: isRequired,
    sortOrder: 0,
    items: items ??
        [
          testModifierOption(),
          testModifierOption(
            id: 'mi-unagi',
            name: 'Унаги',
            sortOrder: 1,
          ),
          testModifierOption(
            id: 'mi-soy',
            name: 'Соевый',
            price: Money.zero,
            sortOrder: 2,
          ),
        ],
  );
}

MenuItem testMenuItem({
  String id = 'item-philadelphia',
  String sku = 'R-001',
  String name = 'Филадельфия',
  String categoryId = 'cat-rolls',
  String categoryName = 'Роллы',
  Money price = const Money.kopecks(39000),
  bool isHalal = false,
  bool isPopular = false,
  bool isNew = false,
  bool isAvailable = true,
  bool stopListed = false,
  String? stopReason,
  int? weight = 250,
  List<ModifierGroup> modifierGroups = const [],
}) {
  return MenuItem(
    id: id,
    brandId: 'brand-shik-roll',
    menuId: 'menu-main',
    sku: sku,
    name: name,
    slug: id,
    description: 'Описание позиции',
    category: MenuItemCategoryRef(
      id: categoryId,
      name: categoryName,
      menuId: 'menu-main',
    ),
    weight: weight,
    status: MenuItemStatus.published,
    sortOrder: 0,
    isPopular: isPopular,
    isNew: isNew,
    isFeatured: false,
    isHalal: isHalal,
    available: isAvailable && !stopListed,
    price: MenuItemPrice(base: price, effective: price, currency: 'RUB'),
    availability: BranchAvailability(isAvailable: isAvailable),
    stopList: StopListStatus(isActive: stopListed, reason: stopReason),
    certifications: [
      if (isHalal)
        const Certification(tagId: 'tag-halal', code: 'HALAL', name: 'Халяль'),
    ],
    modifierGroups: modifierGroups,
  );
}
