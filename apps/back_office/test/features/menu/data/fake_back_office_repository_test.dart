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
        items.map((e) => e.categoryName).toSet(),
        containsAll(FakeBackOfficeRepository.categories.map((c) => c.name)),
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
      final draft = MenuItemDraft(
        name: 'Новый ролл',
        description: 'Тест',
        categoryId: FakeBackOfficeRepository.categoryRolls.id,
        price: const Money(19900),
        isHalal: true,
      );
      final created = await repository.createMenuItem(draft);
      expect(created.id, isNotEmpty);
      expect(created.isAvailable, isTrue);
      expect(created.name, 'Новый ролл');
      expect(created.categoryName, 'Роллы');
      final items = await repository.fetchMenuItems(branchId: 'branch-center');
      expect(items.map((e) => e.id), contains(created.id));
    });
  });

  group('updateMenuItem', () {
    test('moves the item to the category the draft names', () async {
      final items = await repository.fetchMenuItems(branchId: 'branch-center');
      final target = items.first;
      final updated = await repository.updateMenuItem(
        id: target.id,
        draft: MenuItemDraft(
          name: 'Переименовано',
          description: target.description,
          categoryId: FakeBackOfficeRepository.categoryBurgers.id,
          price: const Money(100),
        ),
      );
      expect(updated.name, 'Переименовано');
      expect(updated.price, const Money(100));
      expect(updated.categoryId, FakeBackOfficeRepository.categoryBurgers.id);
      expect(updated.categoryName, 'Бургеры');

      final reloaded = await repository.fetchMenuItems(
        branchId: 'branch-center',
      );
      final stored = reloaded.firstWhere((e) => e.id == target.id);
      expect(stored.categoryName, 'Бургеры');
    });

    test('throws for unknown id', () {
      expect(
        () => repository.updateMenuItem(
          id: 'nope',
          draft: MenuItemDraft(
            name: 'x',
            description: '',
            categoryId: FakeBackOfficeRepository.categoryRolls.id,
            price: Money.zero,
          ),
        ),
        throwsA(isA<BackOfficeApiException>()),
      );
    });

    test('rejects an unknown categoryId like the API does', () {
      expect(
        () => repository.updateMenuItem(
          id: 'demo-1',
          draft: const MenuItemDraft(
            name: 'x',
            description: '',
            categoryId: 'no-such-category',
            price: Money.zero,
          ),
        ),
        throwsA(isA<BackOfficeApiException>()),
      );
    });
  });
}
