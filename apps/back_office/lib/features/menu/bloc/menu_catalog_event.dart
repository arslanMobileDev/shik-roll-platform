import 'package:equatable/equatable.dart';

import '../data/models/menu_item.dart';

sealed class MenuCatalogEvent extends Equatable {
  const MenuCatalogEvent();

  @override
  List<Object?> get props => [];
}

/// (Re)load the catalog for [branchId].
final class MenuCatalogRequested extends MenuCatalogEvent {
  const MenuCatalogRequested({required this.branchId});

  final String branchId;

  @override
  List<Object?> get props => [branchId];
}

/// Filter the table by category; `null` clears the filter.
final class MenuCategoryFilterChanged extends MenuCatalogEvent {
  const MenuCategoryFilterChanged(this.category);

  final MenuCategory? category;

  @override
  List<Object?> get props => [category];
}

/// Quick stop-list switch in the table row.
final class MenuItemStopListToggled extends MenuCatalogEvent {
  const MenuItemStopListToggled(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Clears the transient snackbar notice after the UI showed it.
final class MenuCatalogNoticeConsumed extends MenuCatalogEvent {
  const MenuCatalogNoticeConsumed();
}

/// Create ([editingId] == null) or update a catalog position from the
/// form dialog.
final class MenuItemSubmitted extends MenuCatalogEvent {
  const MenuItemSubmitted({required this.draft, this.editingId});

  final MenuItemDraft draft;
  final String? editingId;

  @override
  List<Object?> get props => [draft, editingId];
}
