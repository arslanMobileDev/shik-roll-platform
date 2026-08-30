import '../../../core/utils/money.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';

/// In-memory demo catalog for development and widget tests.
///
/// Used when `API_BASE_URL` is not configured; mirrors the Menu & Product
/// API contract shapes so the UI behaves identically against both sources.
final class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({this.latency = const Duration(milliseconds: 250)});

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  static const _brandId = 'brand-shik-roll';
  static const _menuId = 'menu-main';

  static final _categories = <Category>[
    const Category(
      id: 'cat-rolls',
      brandId: _brandId,
      menuId: _menuId,
      name: 'Роллы',
      sortOrder: 0,
      isActive: true,
      itemCount: 5,
    ),
    const Category(
      id: 'cat-baked',
      brandId: _brandId,
      menuId: _menuId,
      name: 'Запечённые роллы',
      sortOrder: 1,
      isActive: true,
      itemCount: 2,
    ),
    const Category(
      id: 'cat-sets',
      brandId: _brandId,
      menuId: _menuId,
      name: 'Сеты',
      sortOrder: 2,
      isActive: true,
      itemCount: 2,
    ),
    const Category(
      id: 'cat-sushi',
      brandId: _brandId,
      menuId: _menuId,
      name: 'Суши и гунканы',
      sortOrder: 3,
      isActive: true,
      itemCount: 2,
    ),
    const Category(
      id: 'cat-drinks',
      brandId: _brandId,
      menuId: _menuId,
      name: 'Напитки',
      sortOrder: 4,
      isActive: true,
      itemCount: 2,
    ),
    const Category(
      id: 'cat-desserts',
      brandId: _brandId,
      menuId: _menuId,
      name: 'Десерты',
      sortOrder: 5,
      isActive: true,
      itemCount: 1,
    ),
  ];

  static ModifierGroup _portionGroup() => const ModifierGroup(
    id: 'mg-portion',
    name: 'Порция',
    selectionType: ModifierSelectionType.single,
    minSelected: 1,
    maxSelected: 1,
    isRequired: true,
    sortOrder: 0,
    items: [
      ModifierItem(
        id: 'mi-portion-standard',
        name: 'Стандарт',
        price: _zero,
        currency: 'RUB',
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-portion-large',
        name: 'Большая',
        price: _p150,
        currency: 'RUB',
        sortOrder: 1,
      ),
    ],
  );

  static const _zero = Money.kopecks(0);
  static const _p40 = Money.kopecks(4000);
  static const _p60 = Money.kopecks(6000);
  static const _p90 = Money.kopecks(9000);
  static const _p120 = Money.kopecks(12000);
  static const _p150 = Money.kopecks(15000);

  static ModifierGroup _addonGroup() => const ModifierGroup(
    id: 'mg-addon',
    name: 'Добавки',
    selectionType: ModifierSelectionType.multiple,
    minSelected: 0,
    maxSelected: 3,
    isRequired: false,
    sortOrder: 1,
    items: [
      ModifierItem(
        id: 'mi-addon-cheese',
        name: 'Сыр сливочный',
        price: _p60,
        currency: 'RUB',
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-addon-avocado',
        name: 'Авокадо',
        price: _p90,
        currency: 'RUB',
        sortOrder: 1,
      ),
      ModifierItem(
        id: 'mi-addon-tobiko',
        name: 'Икра тобико',
        price: _p120,
        currency: 'RUB',
        sortOrder: 2,
      ),
      ModifierItem(
        id: 'mi-addon-cucumber',
        name: 'Огурец',
        price: _p40,
        currency: 'RUB',
        sortOrder: 3,
      ),
    ],
  );

  static ModifierGroup _sauceGroup() => const ModifierGroup(
    id: 'mg-sauce',
    name: 'Соус',
    selectionType: ModifierSelectionType.multiple,
    minSelected: 0,
    maxSelected: 2,
    isRequired: false,
    sortOrder: 2,
    items: [
      ModifierItem(
        id: 'mi-sauce-spicy',
        name: 'Спайси',
        price: _p40,
        currency: 'RUB',
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-sauce-unagi',
        name: 'Унаги',
        price: _p40,
        currency: 'RUB',
        sortOrder: 1,
      ),
      ModifierItem(
        id: 'mi-sauce-soy',
        name: 'Соевый',
        price: _zero,
        currency: 'RUB',
        sortOrder: 2,
      ),
    ],
  );

  static ModifierGroup _weightGroup() => const ModifierGroup(
    id: 'mg-weight',
    name: 'Вес',
    selectionType: ModifierSelectionType.single,
    minSelected: 1,
    maxSelected: 1,
    isRequired: true,
    sortOrder: 0,
    items: [
      ModifierItem(
        id: 'mi-weight-200',
        name: '200 г',
        price: _zero,
        currency: 'RUB',
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-weight-300',
        name: '300 г',
        price: _p90,
        currency: 'RUB',
        sortOrder: 1,
      ),
    ],
  );

  static MenuItem _item({
    required String id,
    required String sku,
    required String name,
    required String categoryId,
    required String categoryName,
    required int priceKopecks,
    int sortOrder = 0,
    int? weight,
    int? calories,
    bool isHalal = false,
    bool isPopular = false,
    bool isNew = false,
    bool isFeatured = false,
    bool isAvailable = true,
    bool stopListed = false,
    String? stopReason,
    List<ModifierGroup> modifierGroups = const [],
    String? description,
  }) {
    final money = Money.kopecks(priceKopecks);
    return MenuItem(
      id: id,
      brandId: _brandId,
      menuId: _menuId,
      sku: sku,
      name: name,
      slug: id,
      description: description,
      category: MenuItemCategoryRef(
        id: categoryId,
        name: categoryName,
        menuId: _menuId,
      ),
      weight: weight,
      calories: calories,
      status: MenuItemStatus.published,
      sortOrder: sortOrder,
      isPopular: isPopular,
      isNew: isNew,
      isFeatured: isFeatured,
      isHalal: isHalal,
      available: isAvailable && !stopListed,
      price: MenuItemPrice(base: money, effective: money, currency: 'RUB'),
      availability: BranchAvailability(isAvailable: isAvailable),
      stopList: StopListStatus(isActive: stopListed, reason: stopReason),
      certifications: [
        if (isHalal)
          const Certification(
            tagId: 'tag-halal',
            code: 'HALAL',
            name: 'Халяль',
          ),
      ],
      modifierGroups: modifierGroups,
    );
  }

  static List<MenuItem> _buildItems() => [
    _item(
      id: 'item-philadelphia',
      sku: 'R-001',
      name: 'Филадельфия',
      categoryId: 'cat-rolls',
      categoryName: 'Роллы',
      priceKopecks: 39000,
      weight: 250,
      calories: 520,
      isPopular: true,
      description: 'Лосось, сыр сливочный, огурец, рис, нори.',
      modifierGroups: [_portionGroup(), _addonGroup(), _sauceGroup()],
    ),
    _item(
      id: 'item-california',
      sku: 'R-002',
      name: 'Калифорния',
      categoryId: 'cat-rolls',
      categoryName: 'Роллы',
      priceKopecks: 34000,
      weight: 240,
      isHalal: true,
      description: 'Краб, авокадо, огурец, икра тобико.',
      modifierGroups: [_portionGroup(), _sauceGroup()],
    ),
    _item(
      id: 'item-dragon',
      sku: 'R-003',
      name: 'Дракон',
      categoryId: 'cat-rolls',
      categoryName: 'Роллы',
      priceKopecks: 52000,
      weight: 280,
      isFeatured: true,
      description: 'Угорь, авокадо, сыр, соус унаги.',
      modifierGroups: [_addonGroup(), _sauceGroup()],
    ),
    _item(
      id: 'item-veggie',
      sku: 'R-004',
      name: 'Овощной ролл',
      categoryId: 'cat-rolls',
      categoryName: 'Роллы',
      priceKopecks: 26000,
      weight: 220,
      isHalal: true,
      isNew: true,
      description: 'Авокадо, огурец, болгарский перец, салат.',
      modifierGroups: [_addonGroup()],
    ),
    _item(
      id: 'item-spicy-chicken',
      sku: 'R-005',
      name: 'Спайси чикен',
      categoryId: 'cat-rolls',
      categoryName: 'Роллы',
      priceKopecks: 31000,
      weight: 235,
      isHalal: true,
      stopListed: true,
      stopReason: 'Нет курицы на филиале',
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-baked-salmon',
      sku: 'B-001',
      name: 'Запечённый с лососем',
      categoryId: 'cat-baked',
      categoryName: 'Запечённые роллы',
      priceKopecks: 42000,
      weight: 260,
      isPopular: true,
      modifierGroups: [_portionGroup(), _sauceGroup()],
    ),
    _item(
      id: 'item-baked-eel',
      sku: 'B-002',
      name: 'Запечённый с угрём',
      categoryId: 'cat-baked',
      categoryName: 'Запечённые роллы',
      priceKopecks: 48000,
      weight: 260,
      isAvailable: false,
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-set-classic',
      sku: 'S-001',
      name: 'Сет «Классика»',
      categoryId: 'cat-sets',
      categoryName: 'Сеты',
      priceKopecks: 119000,
      weight: 900,
      isPopular: true,
      description: '32 шт.: Филадельфия, Калифорния, запечённые.',
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-set-halal',
      sku: 'S-002',
      name: 'Сет «Халяль»',
      categoryId: 'cat-sets',
      categoryName: 'Сеты',
      priceKopecks: 99000,
      weight: 760,
      isHalal: true,
      isFeatured: true,
      description: '24 шт. без свинины и алкогольных соусов.',
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-sushi-salmon',
      sku: 'N-001',
      name: 'Суши с лососем',
      categoryId: 'cat-sushi',
      categoryName: 'Суши и гунканы',
      priceKopecks: 12000,
      weight: 45,
      modifierGroups: [_weightGroup()],
    ),
    _item(
      id: 'item-gunkan-tobiko',
      sku: 'N-002',
      name: 'Гункан с тобико',
      categoryId: 'cat-sushi',
      categoryName: 'Суши и гунканы',
      priceKopecks: 14000,
      weight: 50,
      isNew: true,
      modifierGroups: [_weightGroup()],
    ),
    _item(
      id: 'item-mors',
      sku: 'D-001',
      name: 'Морс клюквенный',
      categoryId: 'cat-drinks',
      categoryName: 'Напитки',
      priceKopecks: 9000,
      weight: 400,
      isHalal: true,
    ),
    _item(
      id: 'item-green-tea',
      sku: 'D-002',
      name: 'Чай зелёный',
      categoryId: 'cat-drinks',
      categoryName: 'Напитки',
      priceKopecks: 7000,
      weight: 350,
      isHalal: true,
    ),
    _item(
      id: 'item-mochi',
      sku: 'DS-001',
      name: 'Моти ассорти',
      categoryId: 'cat-desserts',
      categoryName: 'Десерты',
      priceKopecks: 24000,
      weight: 120,
      isNew: true,
      modifierGroups: [_addonGroup()],
    ),
  ];

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Paged<T> _page<T>(List<T> all, int page, int limit) {
    final start = (page - 1) * limit;
    final slice = start >= all.length
        ? <T>[]
        : all.sublist(
            start,
            (start + limit) > all.length ? all.length : start + limit,
          );
    final totalPages = all.isEmpty ? 0 : (all.length + limit - 1) ~/ limit;
    return Paged<T>(
      data: slice,
      page: page,
      limit: limit,
      total: all.length,
      totalPages: totalPages,
    );
  }

  @override
  Future<Paged<Menu>> getMenus({
    String? brandId,
    String? branchId,
    int page = 1,
    int limit = 20,
  }) async {
    await _simulateLatency();
    final menus = [
      const Menu(
        id: _menuId,
        brandId: _brandId,
        name: 'Основное меню',
        status: 'PUBLISHED',
        categoryCount: 6,
      ),
    ].where((m) => brandId == null || m.brandId == brandId).toList();
    return _page(menus, page, limit);
  }

  @override
  Future<Paged<Category>> getCategories({
    String? menuId,
    String? brandId,
    int page = 1,
    int limit = 100,
  }) async {
    await _simulateLatency();
    final categories = _categories
        .where(
          (c) =>
              (menuId == null || c.menuId == menuId) &&
              (brandId == null || c.brandId == brandId),
        )
        .toList();
    return _page(categories, page, limit);
  }

  @override
  Future<Paged<MenuItem>> getMenuItems({
    required String brandId,
    String? branchId,
    String? categoryId,
    bool? isHalal,
    bool? availableOnly,
    String? search,
    int page = 1,
    int limit = 30,
  }) async {
    await _simulateLatency();
    var items = _buildItems().where((i) => i.brandId == brandId);
    if (categoryId != null) {
      items = items.where((i) => i.category.id == categoryId);
    }
    if (isHalal ?? false) {
      items = items.where((i) => i.isHalal);
    }
    if (availableOnly ?? false) {
      items = items.where((i) => i.available);
    }
    final query = search?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      items = items.where(
        (i) =>
            i.name.toLowerCase().contains(query) ||
            i.sku.toLowerCase().contains(query) ||
            (i.description?.toLowerCase().contains(query) ?? false),
      );
    }
    final sorted = items.toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return _page(sorted, page, limit);
  }
}
