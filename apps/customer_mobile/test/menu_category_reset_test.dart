import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/features/menu/bloc/menu_bloc.dart';
import 'package:customer_mobile/features/menu/bloc/menu_event.dart';
import 'package:customer_mobile/features/menu/bloc/menu_state.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/menu/data/menu_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMenuRepository extends Mock implements CustomerMenuRepository {}

void main() {
  const selected = MenuState(
    status: MenuStatus.loaded,
    selectedCategoryId: 'rolls',
  );

  test('copyWith preserves, replaces and explicitly clears the category', () {
    expect(selected.copyWith().selectedCategoryId, 'rolls');
    expect(
      selected.copyWith(selectedCategoryId: null).selectedCategoryId,
      'rolls',
    );
    expect(
      selected.copyWith(selectedCategoryId: 'sushi').selectedCategoryId,
      'sushi',
    );
    expect(selected.copyWith(clearCategory: true).selectedCategoryId, isNull);
    expect(
      selected
          .copyWith(clearCategory: true, selectedCategoryId: 'sushi')
          .selectedCategoryId,
      isNull,
    );
  });

  final repository = MockMenuRepository();
  blocTest<MenuBloc, MenuState>(
    'All clears the selected category before requesting unfiltered items',
    setUp: () {
      when(() => repository.getCategories()).thenAnswer(
        (_) async =>
            const Paged<Category>(data: [], page: 1, hasNextPage: false),
      );
      when(
        () => repository.getMenuItems(categoryId: null, limit: 50),
      ).thenAnswer(
        (_) async =>
            const Paged<MenuItem>(data: [], page: 1, hasNextPage: false),
      );
    },
    build: () => MenuBloc(repository: repository),
    seed: () => selected,
    act: (bloc) => bloc.add(MenuCategorySelected(null)),
    expect: () => [
      const MenuState(status: MenuStatus.loading),
      const MenuState(status: MenuStatus.loaded),
    ],
    verify: (_) {
      verify(
        () => repository.getMenuItems(categoryId: null, limit: 50),
      ).called(1);
    },
  );
}
