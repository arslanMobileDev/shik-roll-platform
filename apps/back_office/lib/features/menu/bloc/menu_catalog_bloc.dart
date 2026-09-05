import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/back_office_repository.dart';
import '../data/models/menu_item.dart';
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
    on<MenuCatalogNoticeConsumed>(_onNoticeConsumed);
  }

  final BackOfficeRepository _repository;

  Future<void> _onRequested(
    MenuCatalogRequested event,
    Emitter<MenuCatalogState> emit,
  ) async {
    emit(
      state.copyWith(
        status: MenuCatalogStatus.loading,
        branchId: event.branchId,
        clearError: true,
        clearNotice: true,
        clearCategoryFilter: true,
      ),
    );
    try {
      final items = await _repository.fetchMenuItems(
        branchId: event.branchId,
      );
      emit(state.copyWith(status: MenuCatalogStatus.ready, items: items));
    } on Object catch (e) {
      emit(
        state.copyWith(
          status: MenuCatalogStatus.failure,
          errorMessage: 'Не удалось загрузить меню: $e',
        ),
      );
    }
  }

  void _onFilterChanged(
    MenuCategoryFilterChanged event,
    Emitter<MenuCatalogState> emit,
  ) {
    if (event.category == null) {
      emit(state.copyWith(clearCategoryFilter: true));
    } else {
      emit(state.copyWith(categoryFilter: event.category));
    }
  }

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
        final existing = state.items.firstWhere((e) => e.id == editingId);
        final updated = await _repository.updateMenuItem(
          MenuItem(
            id: existing.id,
            name: event.draft.name,
            description: event.draft.description,
            category: event.draft.category,
            price: event.draft.price,
            imageUrl: event.draft.imageUrl,
            isHalal: event.draft.isHalal,
            isAvailable: existing.isAvailable,
          ),
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
