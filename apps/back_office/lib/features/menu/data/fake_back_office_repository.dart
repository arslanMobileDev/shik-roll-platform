import '../../../core/utils/money.dart';
import 'back_office_repository.dart';
import 'models/menu_item.dart';

/// In-memory demo repository used while the backend is offline.
///
/// Stop-list state is tracked per branch: [setStopList] only affects
/// the branch passed in, and [fetchMenuItems] resolves `isAvailable`
/// against that branch's stop-list.
final class FakeBackOfficeRepository implements BackOfficeRepository {
  FakeBackOfficeRepository({this.latency = const Duration(milliseconds: 200)});

  final Duration latency;

  int _nextId = 100;

  final Map<String, Set<String>> _stoppedByBranch = {
    'branch-center': {'demo-6'},
  };

  final List<MenuItem> _items = [
    const MenuItem(
      id: 'demo-1',
      name: 'Филадельфия классик',
      description: 'Лосось, сливочный сыр, огурец, рис, нори. 8 шт.',
      category: MenuCategory.rolls,
      price: Money(44900),
      isHalal: true,
      isAvailable: true,
    ),
    const MenuItem(
      id: 'demo-2',
      name: 'Калифорния с креветкой',
      description: 'Креветка темпура, авокадо, икра тобико. 8 шт.',
      category: MenuCategory.rolls,
      price: Money(39900),
      isHalal: true,
      isAvailable: true,
    ),
    const MenuItem(
      id: 'demo-3',
      name: 'Сет «Халяль Микс»',
      description: '32 шт.: филадельфия, калифорния, спайси цыплёнок.',
      category: MenuCategory.sets,
      price: Money(129900),
      isHalal: true,
      isAvailable: true,
    ),
    const MenuItem(
      id: 'demo-4',
      name: 'ШИК бургер',
      description: 'Котлета из мраморной говядины, чеддер, фирменный соус.',
      category: MenuCategory.burgers,
      price: Money(34900),
      isHalal: true,
      isAvailable: true,
    ),
    const MenuItem(
      id: 'demo-5',
      name: 'Чикен стрипсы',
      description: 'Хрустящие полоски куриного филе, соус на выбор.',
      category: MenuCategory.fastfood,
      price: Money(24900),
      isHalal: true,
      isAvailable: true,
    ),
    const MenuItem(
      id: 'demo-6',
      name: 'Картофель фри',
      description: 'С морской солью, соус барбекю.',
      category: MenuCategory.fastfood,
      price: Money(14900),
      isHalal: true,
      isAvailable: false,
    ),
    const MenuItem(
      id: 'demo-7',
      name: 'Морс облепиховый 0,4 л',
      description: 'Домашний морс из облепихи.',
      category: MenuCategory.drinks,
      price: Money(12900),
      isHalal: true,
      isAvailable: true,
    ),
    const MenuItem(
      id: 'demo-8',
      name: 'Спайси ролл с цыплёнком',
      description: 'Цыплёнок темпура, спайси соус, огурец. 8 шт.',
      category: MenuCategory.rolls,
      price: Money(32900),
      isHalal: true,
      isAvailable: true,
    ),
  ];

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
    final item = MenuItem(
      id: 'demo-${_nextId++}',
      name: draft.name,
      description: draft.description,
      category: draft.category,
      price: draft.price,
      imageUrl: draft.imageUrl,
      isHalal: draft.isHalal,
      isAvailable: true,
    );
    _items.add(item);
    return item;
  }

  @override
  Future<MenuItem> updateMenuItem(MenuItem item) async {
    await Future<void>.delayed(latency);
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index == -1) {
      throw BackOfficeApiException('Позиция ${item.id} не найдена');
    }
    // Availability is branch-scoped; keep the catalog value untouched.
    final updated = _items[index].copyWith(
      name: item.name,
      description: item.description,
      category: item.category,
      price: item.price,
      imageUrl: item.imageUrl,
      isHalal: item.isHalal,
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
