import 'package:equatable/equatable.dart';

import '../data/models/menu_item.dart';

enum MenuCatalogStatus { initial, loading, ready, failure }

final class MenuCatalogState extends Equatable {
  const MenuCatalogState({
    this.status = MenuCatalogStatus.initial,
    this.items = const [],
    this.branchId = '',
    this.categoryFilter,
    this.pendingItemIds = const {},
    this.errorMessage,
    this.notice,
  });

  final MenuCatalogStatus status;
  final List<MenuItem> items;

  /// Branch the catalog was loaded for.
  final String branchId;

  /// Active category filter; `null` = all categories.
  final MenuCategory? categoryFilter;

  /// Ids with an in-flight stop-list mutation.
  final Set<String> pendingItemIds;

  /// Fatal load error.
  final String? errorMessage;

  /// Transient snackbar text (mutation result). Not part of [props]
  /// equality would swallow repeats — it IS part, UI clears it after show.
  final String? notice;

  /// Items after applying the category filter.
  List<MenuItem> get visibleItems => categoryFilter == null
      ? items
      : items.where((e) => e.category == categoryFilter).toList();

  /// Items currently on the branch stop-list.
  List<MenuItem> get stoppedItems =>
      items.where((e) => !e.isAvailable).toList();

  MenuCatalogState copyWith({
    MenuCatalogStatus? status,
    List<MenuItem>? items,
    String? branchId,
    MenuCategory? categoryFilter,
    bool clearCategoryFilter = false,
    Set<String>? pendingItemIds,
    String? errorMessage,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
  }) {
    return MenuCatalogState(
      status: status ?? this.status,
      items: items ?? this.items,
      branchId: branchId ?? this.branchId,
      categoryFilter: clearCategoryFilter
          ? null
          : (categoryFilter ?? this.categoryFilter),
      pendingItemIds: pendingItemIds ?? this.pendingItemIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    branchId,
    categoryFilter,
    pendingItemIds,
    errorMessage,
    notice,
  ];
}
