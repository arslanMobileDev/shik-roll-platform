import 'package:equatable/equatable.dart';

sealed class CatalogEvent extends Equatable {
  const CatalogEvent();

  @override
  List<Object?> get props => [];
}

/// Loads categories and the first page of published items for the
/// brand/branch context. Also used when the context changes.
final class CatalogStarted extends CatalogEvent {
  const CatalogStarted({required this.brandId, this.branchId});

  final String brandId;
  final String? branchId;

  @override
  List<Object?> get props => [brandId, branchId];
}

/// Selects a category filter; `null` means "all categories".
final class CatalogCategorySelected extends CatalogEvent {
  const CatalogCategorySelected(this.categoryId);

  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// Toggles the HALAL-only filter.
final class CatalogHalalFilterChanged extends CatalogEvent {
  const CatalogHalalFilterChanged(this.halalOnly);

  final bool halalOnly;

  @override
  List<Object?> get props => [halalOnly];
}

/// Updates the free-text search query (name, SKU, description).
final class CatalogSearchChanged extends CatalogEvent {
  const CatalogSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Requests the next page of items (dynamic loading on scroll).
final class CatalogNextPageRequested extends CatalogEvent {
  const CatalogNextPageRequested();
}

/// Reloads categories and items from scratch.
final class CatalogRefreshed extends CatalogEvent {
  const CatalogRefreshed();
}
