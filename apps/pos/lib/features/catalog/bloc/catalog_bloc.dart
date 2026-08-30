import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

/// Loads the published catalog for the POS cashier screen.
///
/// Query contract (API-706 / BE-906): items are always requested with
/// `status: PUBLISHED`, brand/branch context, and the active category,
/// HALAL and search filters. Items are appended page by page as the
/// cashier scrolls.
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc({required this._repository}) : super(const CatalogState()) {
    on<CatalogStarted>(_onStarted);
    on<CatalogCategorySelected>(_onCategorySelected);
    on<CatalogHalalFilterChanged>(_onHalalChanged);
    on<CatalogSearchChanged>(_onSearchChanged);
    on<CatalogNextPageRequested>(_onNextPage);
    on<CatalogRefreshed>(_onRefreshed);
  }

  final CatalogRepository _repository;

  static const int _pageSize = 30;

  String _brandId = '';
  String? _branchId;

  Future<void> _onStarted(
    CatalogStarted event,
    Emitter<CatalogState> emit,
  ) async {
    _brandId = event.brandId;
    _branchId = event.branchId;
    emit(
      const CatalogState(status: CatalogStatus.loading),
    );
    await _loadFirstPage(emit);
  }

  Future<void> _onCategorySelected(
    CatalogCategorySelected event,
    Emitter<CatalogState> emit,
  ) async {
    if (event.categoryId == state.selectedCategoryId) return;
    emit(
      state.copyWith(
        status: CatalogStatus.loading,
        selectedCategoryId: event.categoryId,
        items: const [],
      ),
    );
    await _loadFirstPage(emit, keepCategories: true);
  }

  Future<void> _onHalalChanged(
    CatalogHalalFilterChanged event,
    Emitter<CatalogState> emit,
  ) async {
    if (event.halalOnly == state.halalOnly) return;
    emit(
      state.copyWith(
        status: CatalogStatus.loading,
        halalOnly: event.halalOnly,
        items: const [],
      ),
    );
    await _loadFirstPage(emit, keepCategories: true);
  }

  Future<void> _onSearchChanged(
    CatalogSearchChanged event,
    Emitter<CatalogState> emit,
  ) async {
    final query = event.query.trim();
    if (query == state.searchQuery) return;
    emit(
      state.copyWith(
        status: CatalogStatus.loading,
        searchQuery: query,
        items: const [],
      ),
    );
    await _loadFirstPage(emit, keepCategories: true);
  }

  Future<void> _onNextPage(
    CatalogNextPageRequested event,
    Emitter<CatalogState> emit,
  ) async {
    if (state.status != CatalogStatus.loaded ||
        !state.hasMore ||
        state.isLoadingMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await _fetchItems(page: state.page + 1);
      emit(
        state.copyWith(
          items: [...state.items, ...result.data],
          page: result.page,
          hasMore: result.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } on CatalogException catch (e) {
      // Keep already loaded items; surface the failure inline.
      emit(
        state.copyWith(isLoadingMore: false, errorMessage: e.message),
      );
    }
  }

  Future<void> _onRefreshed(
    CatalogRefreshed event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    await _loadFirstPage(emit);
  }

  Future<void> _loadFirstPage(
    Emitter<CatalogState> emit, {
    bool keepCategories = false,
  }) async {
    try {
      final categories = keepCategories
          ? state.categories
          : (await _repository.getCategories(brandId: _brandId)).data
                .where((c) => c.isActive)
                .toList();
      final items = await _fetchItems(page: 1);
      emit(
        state.copyWith(
          status: CatalogStatus.loaded,
          categories: categories,
          items: items.data,
          page: items.page,
          hasMore: items.hasNextPage,
          isLoadingMore: false,
          errorMessage: null,
        ),
      );
    } on CatalogException catch (e) {
      emit(
        state.copyWith(
          status: CatalogStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }

  Future<PagedItems> _fetchItems({required int page}) {
    return _repository
        .getMenuItems(
          brandId: _brandId,
          branchId: _branchId,
          categoryId: state.selectedCategoryId,
          isHalal: state.halalOnly ? true : null,
          search: state.searchQuery.isEmpty ? null : state.searchQuery,
          page: page,
          limit: _pageSize,
        )
        .then(
          (p) => PagedItems(
            data: p.data,
            page: p.page,
            hasNextPage: p.hasNextPage,
          ),
        );
  }
}

/// Internal projection of a paged menu-item response.
final class PagedItems {
  const PagedItems({
    required this.data,
    required this.page,
    required this.hasNextPage,
  });

  final List<MenuItem> data;
  final int page;
  final bool hasNextPage;
}
