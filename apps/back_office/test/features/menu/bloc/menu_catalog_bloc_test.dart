import 'package:back_office/core/utils/money.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_bloc.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_event.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_state.dart';
import 'package:back_office/features/menu/data/back_office_repository.dart';
import 'package:back_office/features/menu/data/models/menu_item.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BackOfficeRepository {}

const _roll = MenuItem(
  id: 'r1',
  name: 'Филадельфия',
  description: 'Лосось, сыр',
  category: MenuCategory.rolls,
  price: Money(44900),
  isHalal: true,
  isAvailable: true,
);

const _burger = MenuItem(
  id: 'b1',
  name: 'ШИК бургер',
  description: 'Говядина',
  category: MenuCategory.burgers,
  price: Money(34900),
  isHalal: true,
  isAvailable: true,
);

void main() {
  late _MockRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const MenuItemDraft(
        name: '',
        description: '',
        category: MenuCategory.rolls,
        price: Money.zero,
        isHalal: true,
      ),
    );
    registerFallbackValue(_roll);
  });

  setUp(() {
    repository = _MockRepository();
  });

  MenuCatalogBloc buildBloc() => MenuCatalogBloc(repository: repository);

  group('MenuCatalogRequested', () {
    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'emits loading then ready with fetched items',
      setUp: () {
        when(() => repository.fetchMenuItems(branchId: 'b1'))
            .thenAnswer((_) async => [_roll, _burger]);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const MenuCatalogRequested(branchId: 'b1')),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.status, 'status', MenuCatalogStatus.loading)
            .having((s) => s.branchId, 'branchId', 'b1'),
        isA<MenuCatalogState>()
            .having((s) => s.status, 'status', MenuCatalogStatus.ready)
            .having((s) => s.items.length, 'items', 2),
      ],
    );

    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'emits loading then failure on repository error',
      setUp: () {
        when(() => repository.fetchMenuItems(branchId: 'b1'))
            .thenThrow(const BackOfficeApiException('boom'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const MenuCatalogRequested(branchId: 'b1')),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.status, 'status', MenuCatalogStatus.loading),
        isA<MenuCatalogState>()
            .having((s) => s.status, 'status', MenuCatalogStatus.failure)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('MenuCategoryFilterChanged', () {
    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'filters visibleItems by category and clears on null',
      setUp: () {
        when(() => repository.fetchMenuItems(branchId: 'b1'))
            .thenAnswer((_) async => [_roll, _burger]);
      },
      build: buildBloc,
      seed: () => const MenuCatalogState(
        status: MenuCatalogStatus.ready,
        branchId: 'b1',
        items: [_roll, _burger],
      ),
      act: (bloc) => bloc
        ..add(const MenuCategoryFilterChanged(MenuCategory.rolls))
        ..add(const MenuCategoryFilterChanged(null)),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.categoryFilter, 'filter', MenuCategory.rolls)
            .having((s) => s.visibleItems, 'visible', [_roll]),
        isA<MenuCatalogState>()
            .having((s) => s.categoryFilter, 'filter', isNull)
            .having((s) => s.visibleItems.length, 'visible', 2),
      ],
    );
  });

  group('MenuItemStopListToggled', () {
    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'optimistically stops item, calls repository, sets notice',
      setUp: () {
        when(
          () => repository.setStopList(
            itemId: 'r1',
            branchId: 'b1',
            stopped: true,
          ),
        ).thenAnswer((_) async {});
      },
      build: buildBloc,
      seed: () => const MenuCatalogState(
        status: MenuCatalogStatus.ready,
        branchId: 'b1',
        items: [_roll],
      ),
      act: (bloc) => bloc.add(const MenuItemStopListToggled('r1')),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.items.single.isAvailable, 'available', false)
            .having((s) => s.pendingItemIds, 'pending', {'r1'}),
        isA<MenuCatalogState>()
            .having((s) => s.pendingItemIds, 'pending', isEmpty)
            .having((s) => s.notice, 'notice', contains('стоп-лист')),
      ],
      verify: (_) {
        verify(
          () => repository.setStopList(
            itemId: 'r1',
            branchId: 'b1',
            stopped: true,
          ),
        ).called(1);
      },
    );

    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'rolls back optimistic update on repository error',
      setUp: () {
        when(
          () => repository.setStopList(
            itemId: 'r1',
            branchId: 'b1',
            stopped: true,
          ),
        ).thenThrow(const BackOfficeApiException('network'));
      },
      build: buildBloc,
      seed: () => const MenuCatalogState(
        status: MenuCatalogStatus.ready,
        branchId: 'b1',
        items: [_roll],
      ),
      act: (bloc) => bloc.add(const MenuItemStopListToggled('r1')),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.items.single.isAvailable, 'available', false),
        isA<MenuCatalogState>()
            .having((s) => s.items.single.isAvailable, 'available', true)
            .having((s) => s.notice, 'notice', contains('Ошибка')),
      ],
    );
  });

  group('MenuItemSubmitted', () {
    const draft = MenuItemDraft(
      name: 'Новый ролл',
      description: 'Состав',
      category: MenuCategory.rolls,
      price: Money(19900),
      isHalal: true,
    );

    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'creates item and appends to catalog',
      setUp: () {
        when(() => repository.createMenuItem(any()))
            .thenAnswer((_) async => _roll);
      },
      build: buildBloc,
      seed: () => const MenuCatalogState(
        status: MenuCatalogStatus.ready,
        branchId: 'b1',
        items: [_burger],
      ),
      act: (bloc) => bloc.add(const MenuItemSubmitted(draft: draft)),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.items, 'items', [_burger, _roll])
            .having((s) => s.notice, 'notice', contains('создано')),
      ],
    );

    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'updates existing item preserving availability',
      setUp: () {
        when(() => repository.updateMenuItem(any())).thenAnswer(
          (_) async => _roll.copyWith(name: 'Обновлено', isAvailable: false),
        );
      },
      build: buildBloc,
      seed: () => const MenuCatalogState(
        status: MenuCatalogStatus.ready,
        branchId: 'b1',
        items: [_roll],
      ),
      act: (bloc) =>
          bloc.add(const MenuItemSubmitted(draft: draft, editingId: 'r1')),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.items.single.name, 'name', 'Обновлено')
            .having((s) => s.items.single.isAvailable, 'available', false)
            .having((s) => s.notice, 'notice', contains('обновлено')),
      ],
      verify: (_) {
        final captured = verify(() => repository.updateMenuItem(captureAny()))
            .captured
            .single as MenuItem;
        expect(captured.id, 'r1');
        expect(captured.name, draft.name);
        expect(captured.isAvailable, isTrue);
      },
    );

    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'emits error notice when save fails',
      setUp: () {
        when(() => repository.createMenuItem(any()))
            .thenThrow(const BackOfficeApiException('validation'));
      },
      build: buildBloc,
      seed: () => const MenuCatalogState(
        status: MenuCatalogStatus.ready,
        branchId: 'b1',
      ),
      act: (bloc) => bloc.add(const MenuItemSubmitted(draft: draft)),
      expect: () => [
        isA<MenuCatalogState>()
            .having((s) => s.notice, 'notice', contains('Не удалось')),
      ],
    );
  });

  group('MenuCatalogNoticeConsumed', () {
    blocTest<MenuCatalogBloc, MenuCatalogState>(
      'clears the notice',
      build: buildBloc,
      seed: () => const MenuCatalogState(
        status: MenuCatalogStatus.ready,
        branchId: 'b1',
        notice: 'hi',
      ),
      act: (bloc) => bloc.add(const MenuCatalogNoticeConsumed()),
      expect: () => [
        isA<MenuCatalogState>().having((s) => s.notice, 'notice', isNull),
      ],
    );
  });
}
