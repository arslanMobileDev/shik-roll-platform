import '../../../core/utils/money.dart';
import 'back_office_repository.dart';
import 'models/menu_item.dart';
import 'models/menu_ref.dart';
import 'models/menu_category_ref.dart';

/// In-memory demo repository used while the backend is offline.
///
/// Stop-list state is tracked per branch: [setStopList] only affects
/// the branch passed in, and [fetchMenuItems] resolves `isAvailable`
/// against that branch's stop-list.
final class FakeBackOfficeRepository implements BackOfficeRepository {
  FakeBackOfficeRepository({this.latency = const Duration(milliseconds: 200)});

  final Duration latency;
  static const menuId = '00000000-0000-4000-8000-000000000100';

  // Categories are brand data, so the demo mirrors the API shape (id + name)
  // instead of a local enum the real backend knows nothing about.
  static const categoryRolls = MenuCategoryRef(
    id: '00000000-0000-4000-8000-000000000101',
    name: 'Роллы',
    menuId: menuId,
  );
  static const categorySets = MenuCategoryRef(
    id: '00000000-0000-4000-8000-000000000102',
    name: 'Сеты',
    menuId: menuId,
  );
  static const categoryFastfood = MenuCategoryRef(
    id: '00000000-0000-4000-8000-000000000103',
    name: 'Фастфуд',
    menuId: menuId,
  );
  static const categoryBurgers = MenuCategoryRef(
    id: '00000000-0000-4000-8000-000000000104',
    name: 'Бургеры',
    menuId: menuId,
  );
  static const categoryDrinks = MenuCategoryRef(
    id: '00000000-0000-4000-8000-000000000105',
    name: 'Напитки',
    menuId: menuId,
  );
  static const categories = [
    categoryRolls,
    categorySets,
    categoryFastfood,
    categoryBurgers,
    categoryDrinks,
  ];

  @override
  Future<List<MenuRef>> fetchMenus({required String brandId}) async {
    await Future<void>.delayed(latency);
    return [
      MenuRef(id: menuId, name: 'Демонстрационное меню', brandId: brandId),
    ];
  }

  /// Editable copy of the seed list: the back-office adds and renames
  /// categories at runtime, so [categories] stays the immutable fixture.
  final List<MenuCategoryRef> _categories = [...categories];

  @override
  Future<List<MenuCategoryRef>> fetchCategories({
    required String menuId,
  }) async {
    await Future<void>.delayed(latency);
    if (menuId != FakeBackOfficeRepository.menuId) return [];
    return List.unmodifiable(_categories);
  }

  @override
  Future<MenuCategoryRef> createCategory({
    required String menuId,
    required CategoryDraft draft,
    required int sortOrder,
  }) async {
    await Future<void>.delayed(latency);
    final created = MenuCategoryRef(
      id: 'demo-category-${_nextId++}',
      name: draft.name,
      menuId: menuId,
      description: draft.description,
      sortOrder: sortOrder,
      isActive: draft.isActive,
    );
    _categories.add(created);
    return created;
  }

  @override
  Future<MenuCategoryRef> updateCategory({
    required String id,
    required CategoryDraft draft,
  }) async {
    await Future<void>.delayed(latency);
    final index = _categories.indexWhere((category) => category.id == id);
    if (index == -1) {
      throw BackOfficeApiException('Категория $id не найдена');
    }
    final updated = MenuCategoryRef(
      id: id,
      name: draft.name,
      menuId: _categories[index].menuId,
      description: draft.description,
      sortOrder: _categories[index].sortOrder,
      isActive: draft.isActive,
    );
    _categories[index] = updated;
    return updated;
  }

  int _nextId = 100;

  final Map<String, Set<String>> _stoppedByBranch = {
    'branch-center': {'demo-6'},
  };

  final List<MenuItem> _items = [
    MenuItem(
      id: 'demo-1',
      name: 'Филадельфия классик',
      description: 'Лосось, сливочный сыр, огурец, рис, нори. 8 шт.',
      categoryId: categoryRolls.id,
      categoryName: categoryRolls.name,
      price: const Money(44900),
      isHalal: true,
      isAvailable: true,
    ),
    MenuItem(
      id: 'demo-2',
      name: 'Калифорния с креветкой',
      description: 'Креветка темпура, авокадо, икра тобико. 8 шт.',
      categoryId: categoryRolls.id,
      categoryName: categoryRolls.name,
      price: const Money(39900),
      isHalal: true,
      isAvailable: true,
    ),
    MenuItem(
      id: 'demo-3',
      name: 'Сет «Халяль Микс»',
      description: '32 шт.: филадельфия, калифорния, спайси цыплёнок.',
      categoryId: categorySets.id,
      categoryName: categorySets.name,
      price: const Money(129900),
      isHalal: true,
      isAvailable: true,
    ),
    MenuItem(
      id: 'demo-4',
      name: 'ШИК бургер',
      description: 'Котлета из мраморной говядины, чеддер, фирменный соус.',
      categoryId: categoryBurgers.id,
      categoryName: categoryBurgers.name,
      price: const Money(34900),
      isHalal: true,
      isAvailable: true,
    ),
    MenuItem(
      id: 'demo-5',
      name: 'Чикен стрипсы',
      description: 'Хрустящие полоски куриного филе, соус на выбор.',
      categoryId: categoryFastfood.id,
      categoryName: categoryFastfood.name,
      price: const Money(24900),
      isHalal: true,
      isAvailable: true,
    ),
    MenuItem(
      id: 'demo-6',
      name: 'Картофель фри',
      description: 'С морской солью, соус барбекю.',
      categoryId: categoryFastfood.id,
      categoryName: categoryFastfood.name,
      price: const Money(14900),
      isHalal: true,
      isAvailable: false,
    ),
    MenuItem(
      id: 'demo-7',
      name: 'Морс облепиховый 0,4 л',
      description: 'Домашний морс из облепихи.',
      categoryId: categoryDrinks.id,
      categoryName: categoryDrinks.name,
      price: const Money(12900),
      isHalal: true,
      isAvailable: true,
    ),
    MenuItem(
      id: 'demo-8',
      name: 'Спайси ролл с цыплёнком',
      description: 'Цыплёнок темпура, спайси соус, огурец. 8 шт.',
      categoryId: categoryRolls.id,
      categoryName: categoryRolls.name,
      price: const Money(32900),
      isHalal: true,
      isAvailable: true,
    ),
  ];

  /// Mirrors the API: an unknown `categoryId` is rejected, not silently kept.
  /// Searches [_categories] so a dish can be filed under a freshly created one.
  MenuCategoryRef _category(String id) => _categories.firstWhere(
    (category) => category.id == id,
    orElse: () => throw BackOfficeApiException('Категория $id не найдена'),
  );

  @override
  Future<List<MenuItem>> fetchMenuItems({required String branchId}) async {
    await Future<void>.delayed(latency);
    final stopped = _stoppedByBranch[branchId] ?? const <String>{};
    return [
      for (final item in _items)
        item.copyWith(isAvailable: !stopped.contains(item.id)),
    ];
  }

  @override
  Future<MenuItem> createMenuItem(MenuItemDraft draft) async {
    await Future<void>.delayed(latency);
    final category = _category(draft.categoryId);
    final item = MenuItem(
      id: 'demo-${_nextId++}',
      name: draft.name,
      description: draft.description,
      categoryId: category.id,
      categoryName: category.name,
      price: draft.price,
      imageUrl: draft.imageUrl,
      allergens: draft.allergens,
      isHalal: draft.isHalal,
      isAvailable: true,
    );
    _items.add(item);
    return item;
  }

  @override
  Future<MenuItem> updateMenuItem({
    required String id,
    required MenuItemDraft draft,
  }) async {
    await Future<void>.delayed(latency);
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) {
      throw BackOfficeApiException('Позиция $id не найдена');
    }
    final category = _category(draft.categoryId);
    // Availability is branch-scoped; keep the catalog value untouched.
    final updated = _items[index].copyWith(
      name: draft.name,
      description: draft.description,
      categoryId: category.id,
      categoryName: category.name,
      price: draft.price,
      imageUrl: draft.imageUrl,
      allergens: draft.allergens,
      clearImageUrl: draft.imageUrl == null,
      clearAllergens: draft.allergens == null,
      isHalal: draft.isHalal,
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> setStopList({
    required String itemId,
    required String branchId,
    required bool stopped,
  }) async {
    await Future<void>.delayed(latency);
    final branchStops = _stoppedByBranch.putIfAbsent(branchId, () => {});
    if (stopped) {
      branchStops.add(itemId);
    } else {
      branchStops.remove(itemId);
    }
  }
}
