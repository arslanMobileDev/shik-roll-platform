import 'package:equatable/equatable.dart';

import '../data/catalog_models.dart';

enum CatalogStatus { initial, loading, loaded, failure }

final class CatalogState extends Equatable {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.halalOnly = false,
    this.searchQuery = '',
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final CatalogStatus status;
  final List<Category> categories;
  final List<MenuItem> items;
  final String? selectedCategoryId;
  final bool halalOnly;
  final String searchQuery;

  /// Last loaded page (0 = nothing loaded yet).
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isInitialLoading =>
      status == CatalogStatus.initial || status == CatalogStatus.loading;

  CatalogState copyWith({
    CatalogStatus? status,
    List<Category>? categories,
    List<MenuItem>? items,
    Object? selectedCategoryId = _unset,
    bool? halalOnly,
    String? searchQuery,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    Object? errorMessage = _unset,
  }) {
    return CatalogState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: identical(selectedCategoryId, _unset)
          ? this.selectedCategoryId
          : selectedCategoryId as String?,
      halalOnly: halalOnly ?? this.halalOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => [
    status,
    categories,
    items,
    selectedCategoryId,
    halalOnly,
    searchQuery,
    page,
    hasMore,
    isLoadingMore,
    errorMessage,
  ];
}
