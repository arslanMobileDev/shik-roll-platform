import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/auth/auth_storage.dart';

import '../data/back_office_repository.dart';
import 'menu_catalog_event.dart';
import 'menu_catalog_state.dart';

/// Loads the branch menu catalog and applies stop-list / CRUD mutations.
final class MenuCatalogBloc extends Bloc<MenuCatalogEvent, MenuCatalogState> {
  MenuCatalogBloc({required this._repository})
    : super(const MenuCatalogState()) {
    on<MenuCatalogRequested>(_onRequested);
    on<MenuCategoryFilterChanged>(_onFilterChanged);
    on<MenuItemStopListToggled>(_onStopListToggled);
    on<MenuItemSubmitted>(_onSubmitted);
    on<MenuCategorySubmitted>(_onCategorySubmitted);
    on<MenuCatalogNoticeConsumed>(_onNoticeConsumed);
  }

  final BackOfficeRepository _repository;
  int _loadGeneration = 0;

  Future<void> _onRequested(
    MenuCatalogRequested event,
    Emitter<MenuCatalogState> emit,
  ) async {
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        items: const [],
        menus: const [],
        categories: const [],
        clearSelectedMenu: true,
        status: MenuCatalogStatus.loading,
        branchId: event.branchId,
        clearError: true,
        clearNotice: true,
        clearCategoryFilter: true,
      ),
    );
    var failureMessage = 'Не удалось прочитать профиль сотрудника';
    try {
      final profile = await AuthStorage.getProfile();
      if (generation != _loadGeneration || emit.isDone) return;
      if (profile == null || profile.brandId.trim().isEmpty) {
        emit(
          state.copyWith(
            status: MenuCatalogStatus.failure,
            errorMessage: 'Войдите в аккаунт сотрудника для загрузки меню',
          ),
        );
        return;
      }
      failureMessage = 'Не удалось загрузить меню';
      final menus = await _repository.fetchMenus(brandId: profile.brandId);
      if (generation != _loadGeneration || emit.isDone) return;
      if (menus.isEmpty) {
        emit(
          state.copyWith(
            status: MenuCatalogStatus.failure,
            errorMessage: 'Меню не настроены',
          ),
        );
        return;
      }
      // TODO: offer a menu selector when a brand has several menus; preserve API order for now.
      final menuId = menus.first.id;
      failureMessage = 'Не удалось загрузить категории';
      final categories = await _repository.fetchCategories(menuId: menuId);
      if (generation != _loadGeneration || emit.isDone) return;
      failureMessage = 'Не удалось загрузить блюда';
      final items = await _repository.fetchMenuItems(branchId: event.branchId);
      if (generation != _loadGeneration || emit.isDone) return;
      emit(
        state.copyWith(
          status: MenuCatalogStatus.ready,
          items: items,
          menus: menus,
          categories: categories,
          selectedMenuId: menuId,
        ),
      );
    } on Object {
      if (generation != _loadGeneration || emit.isDone) return;
      emit(
        state.copyWith(
          status: MenuCatalogStatus.failure,
          errorMessage: failureMessage,
        ),
      );
    }
  }

  void _onFilterChanged(
    MenuCategoryFilterChanged event,
    Emitter<MenuCatalogState> emit,
  ) {
    if (event.categoryId == null) {
      emit(state.copyWith(clearCategoryFilter: true));
    } else {
      emit(state.copyWith(categoryFilter: event.categoryId));
    }
  }

  /// Creates a category at the end of the active menu, or renames/hides one.
  ///
  /// Answers through [MenuCategorySubmitted.result] because the dish form has
  /// to select the created category while its own dialog stays open, and a
  /// notice cannot carry a value. Failures land on the same future so their
  /// dialog can render them inline instead of behind a snackbar.
  Future<void> _onCategorySubmitted(
    MenuCategorySubmitted event,
    Emitter<MenuCatalogState> emit,
  ) async {
    try {
      if (event.editingId == null) {
        final menuId = state.selectedMenuId;
        if (menuId == null) {
          throw const BackOfficeApiException('Меню не выбрано');
        }
        final created = await _repository.createCategory(
          menuId: menuId,
          draft: event.draft,
          sortOrder: _nextSortOrder,
        );
        emit(
          state.copyWith(
            categories: [...state.categories, created],
            notice: 'Категория «${created.name}» создана',
          ),
        );
        event.result.complete(created);
      } else {
        final updated = await _repository.updateCategory(
          id: event.editingId!,
          draft: event.draft,
        );
        // Hiding never drops the category from the list: the back-office is
        // where it gets found again and switched back on.
        emit(
          state.copyWith(
            categories: [
              for (final category in state.categories)
                if (category.id == event.editingId) updated else category,
            ],
            notice: event.draft.isActive
                ? 'Категория «${updated.name}» обновлена'
                : 'Категория «${updated.name}» скрыта из меню',
          ),
        );
        event.result.complete(updated);
      }
    } on Object catch (error, stackTrace) {
      event.result.completeError(error, stackTrace);
    }
  }

  /// Appends after the last category of the menu.
  int get _nextSortOrder =>
      state.categories.fold(
        0,
        (max, category) => category.sortOrder > max ? category.sortOrder : max,
      ) +
      1;

  /// Optimistic flip with rollback on failure.
  Future<void> _onStopListToggled(
    MenuItemStopListToggled event,
    Emitter<MenuCatalogState> emit,
  ) async {
    final index = state.items.indexWhere((e) => e.id == event.itemId);
    if (index == -1 || state.pendingItemIds.contains(event.itemId)) return;

    final current = state.items[index];
    final stopped = current.isAvailable; // now available -> will be stopped
    final optimistic = [...state.items]
      ..[index] = current.copyWith(isAvailable: !stopped);
    emit(
      state.copyWith(
        items: optimistic,
        pendingItemIds: {...state.pendingItemIds, event.itemId},
        clearNotice: true,
      ),
    );

    try {
      await _repository.setStopList(
        itemId: event.itemId,
        branchId: state.branchId,
        stopped: stopped,
      );
      emit(
        state.copyWith(
          pendingItemIds: {...state.pendingItemIds}..remove(event.itemId),
          notice: stopped
              ? '«${current.name}» добавлено в стоп-лист'
              : '«${current.name}» снято со стоп-листа',
        ),
      );
    } on Object catch (e) {
      final rolledBack = [
        for (final item in state.items)
          if (item.id == event.itemId) current else item,
      ];
      emit(
        state.copyWith(
          items: rolledBack,
          pendingItemIds: {...state.pendingItemIds}..remove(event.itemId),
          notice: 'Ошибка стоп-листа: $e',
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    MenuItemSubmitted event,
    Emitter<MenuCatalogState> emit,
  ) async {
    final editingId = event.editingId;
    try {
      if (editingId == null) {
        final created = await _repository.createMenuItem(event.draft);
        emit(
          state.copyWith(
            items: [...state.items, created],
            notice: '«${created.name}» создано',
          ),
        );
      } else {
        // The draft carries every editable field, so nothing has to be
        // reassembled here — that is how the old category used to get saved.
        final updated = await _repository.updateMenuItem(
          id: editingId,
          draft: event.draft,
        );
        final items = [
          for (final item in state.items)
            if (item.id == editingId) updated else item,
        ];
        emit(
          state.copyWith(items: items, notice: '«${updated.name}» обновлено'),
        );
      }
    } on Object catch (e) {
      emit(state.copyWith(notice: 'Не удалось сохранить блюдо: $e'));
    }
  }

  void _onNoticeConsumed(
    MenuCatalogNoticeConsumed event,
    Emitter<MenuCatalogState> emit,
  ) {
    emit(state.copyWith(clearNotice: true));
  }
}
