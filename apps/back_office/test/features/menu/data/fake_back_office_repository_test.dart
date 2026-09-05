import 'package:back_office/core/utils/money.dart';
import 'package:back_office/features/menu/data/back_office_repository.dart';
import 'package:back_office/features/menu/data/fake_back_office_repository.dart';
import 'package:back_office/features/menu/data/models/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeBackOfficeRepository repository;

  setUp(() {
    repository = FakeBackOfficeRepository(latency: Duration.zero);
  });

  group('fetchMenuItems', () {
    test('returns seeded catalog', () async {
      final items = await repository.fetchMenuItems(branchId: 'branch-center');
      expect(items, isNotEmpty);
      expect(
        items.map((e) => e.category).toSet(),
        containsAll(MenuCategory.values),
      );
    });

    test('resolves stop-list per branch', () async {
      final center = await repository.fetchMenuItems(branchId: 'branch-center');
      final north = await repository.fetchMenuItems(branchId: 'branch-north');
      final stoppedAtCenter = center.where((e) => !e.isAvailable);
      expect(stoppedAtCenter.map((e) => e.id), contains('demo-6'));
      expect(north.firstWhere((e) => e.id == 'demo-6').isAvailable, isTrue);
    });
  });

  group('setStopList', () {
    test('marks item unavailable only for the given branch', () async {
      await repository.setStopList(
        itemId: 'demo-1',
        branchId: 'branch-north',
        stopped: true,
      );
      final north = await repository.fetchMenuItems(branchId: 'branch-north');
      final center = await repository.fetchMenuItems(branchId: 'branch-center');
      expect(north.firstWhere((e) => e.id == 'demo-1').isAvailable, isFalse);
      expect(center.firstWhere((e) => e.id == 'demo-1').isAvailable, isTrue);
    });

    test('stopped: false removes item from stop-list', () async {
      await repository.setStopList(
        itemId: 'demo-6',
        branchId: 'branch-center',
        stopped: false,
      );
      final items = await repository.fetchMenuItems(branchId: 'branch-center');
      expect(items.firstWhere((e) => e.id == 'demo-6').isAvailable, isTrue);
    });
  });

  group('createMenuItem', () {
    test('creates available item with generated id', () async {
      const draft = MenuItemDraft(
        name: 'Новый ролл',
        description: 'Тест',
        category: MenuCategory.rolls,
        price: Money(19900),
        isHalal: true,
      );
      final created = await repository.createMenuItem(draft);
      expect(created.id, isNotEmpty);
      expect(created.isAvailable, isTrue);
      expect(created.name, 'Новый ролл');
      final items = await repository.fetchMenuItems(branchId: 'branch-center');
      expect(items.map((e) => e.id), contains(created.id));
    });
  });

  group('updateMenuItem', () {
    test('updates fields of existing item', () async {
      final items = await repository.fetchMenuItems(branchId: 'branch-center');
      final target = items.first;
      final updated = await repository.updateMenuItem(
        target.copyWith(name: 'Переименовано', price: const Money(100)),
      );
      expect(updated.name, 'Переименовано');
      expect(updated.price, const Money(100));
      final reloaded = await repository.fetchMenuItems(
        branchId: 'branch-center',
      );
      expect(reloaded.firstWhere((e) => e.id == target.id).name,
          'Переименовано');
    });

    test('throws for unknown id', () {
      const ghost = MenuItem(
        id: 'nope',
        name: 'x',
        description: '',
        category: MenuCategory.rolls,
        price: Money.zero,
        isHalal: true,
        isAvailable: true,
      );
      expect(
        () => repository.updateMenuItem(ghost),
        throwsA(isA<BackOfficeApiException>()),
      );
    });
  });
}
