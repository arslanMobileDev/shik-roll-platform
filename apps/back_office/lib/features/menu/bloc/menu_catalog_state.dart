import 'package:equatable/equatable.dart';

import '../data/models/menu_item.dart';
import '../data/models/menu_ref.dart';
import '../data/models/menu_category_ref.dart';

enum MenuCatalogStatus { initial, loading, ready, failure }

final class MenuCatalogState extends Equatable {
  const MenuCatalogState({
    this.status = MenuCatalogStatus.initial,
    this.items = const [],
    this.menus = const [],
    this.categories = const [],
    this.selectedMenuId,
    this.branchId = '',
    this.categoryFilter,
    this.pendingItemIds = const {},
    this.errorMessage,
    this.notice,
  });

  final MenuCatalogStatus status;
  final List<MenuItem> items;
  final List<MenuRef> menus;
  final List<MenuCategoryRef> categories;
  final String? selectedMenuId;

  /// Branch the catalog was loaded for.
  final String branchId;

  /// Active category filter; `null` = all categories.
  final String? categoryFilter;

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
      : items.where((e) => e.categoryId == categoryFilter).toList();

  /// Items currently on the branch stop-list.
  List<MenuItem> get stoppedItems =>
      items.where((e) => !e.isAvailable).toList();

  MenuCatalogState copyWith({
    MenuCatalogStatus? status,
    List<MenuItem>? items,
    List<MenuRef>? menus,
    List<MenuCategoryRef>? categories,
    String? selectedMenuId,
    bool clearSelectedMenu = false,
    String? branchId,
    String? categoryFilter,
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
      menus: menus ?? this.menus,
      categories: categories ?? this.categories,
      selectedMenuId: clearSelectedMenu
          ? null
          : selectedMenuId ?? this.selectedMenuId,
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
    menus,
    categories,
    selectedMenuId,
    branchId,
    categoryFilter,
    pendingItemIds,
    errorMessage,
    notice,
  ];
}
