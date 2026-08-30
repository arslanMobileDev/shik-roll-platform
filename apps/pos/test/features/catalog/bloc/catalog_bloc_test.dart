import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos/features/catalog/bloc/catalog_bloc.dart';
import 'package:pos/features/catalog/bloc/catalog_event.dart';
import 'package:pos/features/catalog/bloc/catalog_state.dart';
import 'package:pos/features/catalog/data/catalog_models.dart';
import 'package:pos/features/catalog/data/catalog_repository.dart';
import 'package:pos/features/catalog/data/fake_catalog_repository.dart';

import '../../../helpers/test_fixtures.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

void main() {
  group('CatalogBloc with demo repository', () {
    late FakeCatalogRepository repository;

    setUp(() {
      repository = FakeCatalogRepository(latency: Duration.zero);
    });

    CatalogBloc buildBloc() => CatalogBloc(repository: repository);

    blocTest<CatalogBloc, CatalogState>(
      'loads active categories and published items on start',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const CatalogStarted(
          brandId: 'brand-shik-roll',
          branchId: 'branch-central',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.status, CatalogStatus.loaded);
        expect(bloc.state.categories, hasLength(6));
        expect(bloc.state.items, hasLength(14));
        expect(
          bloc.state.items.every((i) => i.status == MenuItemStatus.published),
          isTrue,
        );
        expect(bloc.state.hasMore, isFalse);
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'halal filter keeps only halal-certified items',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(
          const CatalogStarted(
            brandId: 'brand-shik-roll',
            branchId: 'branch-central',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogHalalFilterChanged(true));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.status, CatalogStatus.loaded);
        expect(bloc.state.halalOnly, isTrue);
        expect(bloc.state.items, hasLength(6));
        expect(bloc.state.items.every((i) => i.isHalal), isTrue);
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'category filter keeps only items of the selected category',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(
          const CatalogStarted(
            brandId: 'brand-shik-roll',
            branchId: 'branch-central',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogCategorySelected('cat-drinks'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.items, hasLength(2));
        expect(
          bloc.state.items.every((i) => i.category.id == 'cat-drinks'),
          isTrue,
        );
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'search filters by name, sku or description',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(
          const CatalogStarted(
            brandId: 'brand-shik-roll',
            branchId: 'branch-central',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogSearchChanged('морс'));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.items, hasLength(1));
        expect(bloc.state.items.single.name, 'Морс клюквенный');
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'context change resets filters and reloads',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(
          const CatalogStarted(
            brandId: 'brand-shik-roll',
            branchId: 'branch-central',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogHalalFilterChanged(true));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const CatalogStarted(
            brandId: 'brand-shik-roll',
            branchId: 'branch-north',
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.status, CatalogStatus.loaded);
        expect(bloc.state.halalOnly, isFalse);
        expect(bloc.state.selectedCategoryId, isNull);
        expect(bloc.state.items, hasLength(14));
      },
    );
  });

  group('CatalogBloc pagination and failures', () {
    late MockCatalogRepository repository;

    setUp(() {
      repository = MockCatalogRepository();
    });

    List<MenuItem> items(int from, int count) => [
      for (var i = from; i < from + count; i++)
        testMenuItem(id: 'item-$i', sku: 'SKU-$i', name: 'Позиция $i'),
    ];

    void stubCategories() {
      when(
        () => repository.getCategories(
          menuId: any(named: 'menuId'),
          brandId: any(named: 'brandId'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => Paged(
          data: [testCategory()],
          page: 1,
          limit: 100,
          total: 1,
          totalPages: 1,
        ),
      );
    }

    blocTest<CatalogBloc, CatalogState>(
      'appends the next page while preserving loaded items',
      build: () => CatalogBloc(repository: repository),
      setUp: () {
        stubCategories();
        var requestedPage = 0;
        when(
          () => repository.getMenuItems(
            brandId: any(named: 'brandId'),
            branchId: any(named: 'branchId'),
            categoryId: any(named: 'categoryId'),
            isHalal: any(named: 'isHalal'),
            availableOnly: any(named: 'availableOnly'),
            search: any(named: 'search'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((invocation) async {
          requestedPage = invocation.namedArguments[#page] as int;
          final isFirst = requestedPage == 1;
          return Paged(
            data: isFirst ? items(0, 30) : items(30, 5),
            page: requestedPage,
            limit: 30,
            total: 35,
            totalPages: 2,
          );
        });
      },
      act: (bloc) async {
        bloc.add(
          const CatalogStarted(
            brandId: 'brand-shik-roll',
            branchId: 'branch-central',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogNextPageRequested());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.items, hasLength(35));
        expect(bloc.state.page, 2);
        expect(bloc.state.hasMore, isFalse);
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'ignores page requests when there is no next page',
      build: () => CatalogBloc(repository: repository),
      setUp: () {
        stubCategories();
        when(
          () => repository.getMenuItems(
            brandId: any(named: 'brandId'),
            branchId: any(named: 'branchId'),
            categoryId: any(named: 'categoryId'),
            isHalal: any(named: 'isHalal'),
            availableOnly: any(named: 'availableOnly'),
            search: any(named: 'search'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => Paged(
            data: items(0, 3),
            page: 1,
            limit: 30,
            total: 3,
            totalPages: 1,
          ),
        );
      },
      act: (bloc) async {
        bloc.add(
          const CatalogStarted(
            brandId: 'brand-shik-roll',
            branchId: 'branch-central',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CatalogNextPageRequested());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.items, hasLength(3));
        expect(bloc.state.page, 1);
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'emits failure state when the repository throws',
      build: () => CatalogBloc(repository: repository),
      setUp: () {
        when(
          () => repository.getCategories(
            menuId: any(named: 'menuId'),
            brandId: any(named: 'brandId'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const CatalogException('Сервер недоступен', statusCode: 503));
      },
      act: (bloc) => bloc.add(
        const CatalogStarted(
          brandId: 'brand-shik-roll',
          branchId: 'branch-central',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.status, CatalogStatus.failure);
        expect(bloc.state.errorMessage, 'Сервер недоступен');
      },
    );
  });
}
