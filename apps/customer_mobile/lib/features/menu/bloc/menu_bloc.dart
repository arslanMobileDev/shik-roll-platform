import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/menu_repository.dart';
import 'menu_event.dart';
import 'menu_state.dart';

/// Loads the published guest menu for the customer showcase.
///
/// Query contract (API-706): items are always requested with
/// `status: PUBLISHED`; the client filters by the active category.
class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc({required this._repository}) : super(const MenuState()) {
    on<MenuStarted>(_onStarted);
    on<MenuCategorySelected>(_onCategorySelected);
    on<MenuRefreshed>(_onRefreshed);
  }

  final CustomerMenuRepository _repository;

  Future<void> _onStarted(MenuStarted event, Emitter<MenuState> emit) async {
    emit(const MenuState(status: MenuStatus.loading));
    await _load(emit);
  }

  Future<void> _onCategorySelected(
    MenuCategorySelected event,
    Emitter<MenuState> emit,
  ) async {
    if (event.categoryId == state.selectedCategoryId) return;
    emit(
      state.copyWith(
        status: MenuStatus.loading,
        selectedCategoryId: event.categoryId,
      ),
    );
    await _load(emit, keepCategories: true);
  }

  Future<void> _onRefreshed(
    MenuRefreshed event,
    Emitter<MenuState> emit,
  ) async {
    emit(state.copyWith(status: MenuStatus.loading));
    await _load(emit, keepCategories: true);
  }

  Future<void> _load(
    Emitter<MenuState> emit, {
    bool keepCategories = false,
  }) async {
    try {
      final categories =
          keepCategories && state.categories.isNotEmpty
          ? state.categories
          : (await _repository.getCategories()).data
                .where((c) => c.isActive)
                .toList();
      final items = (await _repository.getMenuItems(
        categoryId: state.selectedCategoryId,
        limit: 50,
      )).data;
      emit(
        MenuState(
          status: MenuStatus.loaded,
          categories: categories,
          items: items,
          selectedCategoryId: state.selectedCategoryId,
        ),
      );
    } on MenuException catch (e) {
      emit(
        MenuState(
          status: MenuStatus.failure,
          categories: state.categories,
          selectedCategoryId: state.selectedCategoryId,
          errorMessage: e.message,
        ),
      );
    }
  }
}
