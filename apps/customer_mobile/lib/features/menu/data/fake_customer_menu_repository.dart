import '../../../core/utils/money.dart';
import 'menu_models.dart';
import 'menu_repository.dart';

/// In-memory demo menu for development and widget tests.
///
/// Used when `API_BASE_URL` is not configured; holds real SHIK ROLL dishes
/// (Филадельфия, сеты, бургеры и др.) so the guest showcase behaves like the
/// remote Menu & Product API.
final class FakeCustomerMenuRepository implements CustomerMenuRepository {
  FakeCustomerMenuRepository({this.latency = Duration.zero});

  /// Simulated network latency; keep [Duration.zero] in tests.
  final Duration latency;

  static const _categories = <Category>[
    Category(id: 'cat-rolls', name: 'Роллы', sortOrder: 0, isActive: true),
    Category(id: 'cat-sets', name: 'Сеты', sortOrder: 1, isActive: true),
    Category(id: 'cat-fastfood', name: 'Фастфуд', sortOrder: 2, isActive: true),
    Category(id: 'cat-burgers', name: 'Бургеры', sortOrder: 3, isActive: true),
    Category(id: 'cat-pizza', name: 'Пицца', sortOrder: 4, isActive: true),
    Category(id: 'cat-drinks', name: 'Напитки', sortOrder: 5, isActive: true),
  ];

  static const _zero = Money.kopecks(0);
  static const _p40 = Money.kopecks(4000);
  static const _p60 = Money.kopecks(6000);
  static const _p90 = Money.kopecks(9000);
  static const _p150 = Money.kopecks(15000);

  static ModifierGroup _portionGroup() => const ModifierGroup(
    id: 'mg-portion',
    name: 'Порция',
    selectionType: ModifierSelectionType.single,
    minSelected: 1,
    maxSelected: 1,
    isRequired: true,
    sortOrder: 0,
    items: [
      ModifierItem(id: 'mi-p-std', name: 'Стандарт', price: _zero, sortOrder: 0),
      ModifierItem(id: 'mi-p-lg', name: 'Большая', price: _p150, sortOrder: 1),
    ],
  );

  static ModifierGroup _sauceGroup() => const ModifierGroup(
    id: 'mg-sauce',
    name: 'Соусы',
    selectionType: ModifierSelectionType.multiple,
    minSelected: 0,
    maxSelected: 2,
    isRequired: false,
    sortOrder: 1,
    items: [
      ModifierItem(id: 'mi-s-spicy', name: 'Спайси', price: _p40, sortOrder: 0),
      ModifierItem(id: 'mi-s-unagi', name: 'Унаги', price: _p40, sortOrder: 1),
      ModifierItem(id: 'mi-s-soy', name: 'Соевый', price: _zero, sortOrder: 2),
    ],
  );

  static ModifierGroup _toppingGroup() => const ModifierGroup(
    id: 'mg-top',
    name: 'Топпинги',
    selectionType: ModifierSelectionType.multiple,
    minSelected: 0,
    maxSelected: 3,
    isRequired: false,
    sortOrder: 2,
    items: [
      ModifierItem(
        id: 'mi-t-cheese',
        name: 'Сыр сливочный',
        price: _p60,
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-t-avocado',
        name: 'Авокадо',
        price: _p90,
        sortOrder: 1,
      ),
      ModifierItem(
        id: 'mi-t-cucumber',
        name: 'Огурец',
        price: _p40,
        sortOrder: 2,
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
    List<ModifierGroup> modifierGroups = const [],
    String? description,
  }) {
    final money = Money.kopecks(priceKopecks);
    return MenuItem(
      id: id,
      sku: sku,
      name: name,
      description: description,
      category: MenuItemCategoryRef(id: categoryId, name: categoryName),
      weight: weight,
      calories: calories,
      price: money,
      sortOrder: sortOrder,
      isPopular: isPopular,
      isNew: isNew,
      isHalal: isHalal,
      available: true,
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
      modifierGroups: [_portionGroup(), _sauceGroup(), _toppingGroup()],
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
      id: 'item-set-classic',
      sku: 'S-001',
      name: 'Сет «Классика»',
      categoryId: 'cat-sets',
      categoryName: 'Сеты',
      priceKopecks: 119000,
      weight: 900,
      calories: 2100,
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
      description: '24 шт. без свинины и алкогольных соусов.',
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-fries',
      sku: 'F-001',
      name: 'Картофель фри',
      categoryId: 'cat-fastfood',
      categoryName: 'Фастфуд',
      priceKopecks: 12000,
      weight: 150,
      isHalal: true,
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-nuggets',
      sku: 'F-002',
      name: 'Наггетсы куриные',
      categoryId: 'cat-fastfood',
      categoryName: 'Фастфуд',
      priceKopecks: 18000,
      weight: 200,
      isHalal: true,
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-burger-chicken',
      sku: 'B-001',
      name: 'Бургер куриный',
      categoryId: 'cat-burgers',
      categoryName: 'Бургеры',
      priceKopecks: 25000,
      weight: 310,
      calories: 640,
      isHalal: true,
      isPopular: true,
      description: 'Котлета куриная, салат, помидор, соус на выбор.',
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-burger-beef',
      sku: 'B-002',
      name: 'Бургер говяжий',
      categoryId: 'cat-burgers',
      categoryName: 'Бургеры',
      priceKopecks: 29000,
      weight: 330,
      isHalal: true,
      description: 'Говядина, сыр чеддер, лук карамельный.',
      modifierGroups: [_sauceGroup()],
    ),
    _item(
      id: 'item-pizza-margarita',
      sku: 'Z-001',
      name: 'Пицца «Маргарита»',
      categoryId: 'cat-pizza',
      categoryName: 'Пицца',
      priceKopecks: 45000,
      weight: 520,
      calories: 1240,
      isHalal: true,
      description: 'Томатный соус, моцарелла, базилик.',
      modifierGroups: [_portionGroup(), _toppingGroup()],
    ),
    _item(
      id: 'item-pizza-chicken',
      sku: 'Z-002',
      name: 'Пицца с курицей',
      categoryId: 'cat-pizza',
      categoryName: 'Пицца',
      priceKopecks: 52000,
      weight: 560,
      isHalal: true,
      isNew: true,
      description: 'Курица гриль, моцарелла, соус цезарь.',
      modifierGroups: [_portionGroup(), _sauceGroup()],
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
      id: 'item-greentea',
      sku: 'D-002',
      name: 'Чай зелёный',
      categoryId: 'cat-drinks',
      categoryName: 'Напитки',
      priceKopecks: 7000,
      weight: 350,
      isHalal: true,
    ),
  ];

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<Paged<Category>> getCategories({String? brandId, int limit = 100}) async {
    await _simulateLatency();
    return Paged(data: _categories, page: 1, hasNextPage: false);
  }

  @override
  Future<Paged<MenuItem>> getMenuItems({
    String? brandId,
    String? categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    await _simulateLatency();
    final all = _buildItems();
    final filtered = categoryId == null
        ? all
        : all.where((i) => i.category.id == categoryId).toList();
    filtered.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
    return Paged(
      data: filtered,
      page: page,
      hasNextPage: filtered.length > page * limit,
    );
  }
}
