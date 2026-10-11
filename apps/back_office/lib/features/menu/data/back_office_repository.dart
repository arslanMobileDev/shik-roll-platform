import 'models/menu_item.dart';
import 'models/menu_ref.dart';
import 'models/menu_category_ref.dart';

/// Menu catalog data source (API-706 v1.2.0 contract).
abstract interface class BackOfficeRepository {
  Future<List<MenuRef>> fetchMenus({required String brandId});

  /// GET /categories?menuId={id}&includeInactive=true — the back-office manages
  /// deactivated categories too, the public catalog does not ask for them.
  Future<List<MenuCategoryRef>> fetchCategories({required String menuId});

  /// POST /categories
  Future<MenuCategoryRef> createCategory({
    required String menuId,
    required CategoryDraft draft,
    required int sortOrder,
  });

  /// PATCH /categories/{id}
  Future<MenuCategoryRef> updateCategory({
    required String id,
    required CategoryDraft draft,
  });

  /// GET /menu-items?branchId={id}
  Future<List<MenuItem>> fetchMenuItems({required String branchId});

  /// POST /menu-items
  Future<MenuItem> createMenuItem(MenuItemDraft draft);

  /// PATCH /menu-items/{id} — [draft] carries every editable field, so callers
  /// cannot accidentally re-save a stale one.
  Future<MenuItem> updateMenuItem({
    required String id,
    required MenuItemDraft draft,
  });

  /// POST /menu-items/{id}/stop-list — adds/removes the item from the
  /// branch stop-list.
  Future<void> setStopList({
    required String itemId,
    required String branchId,
    required bool stopped,
  });
}

/// Domain-level failure surfaced by repositories.
final class BackOfficeApiException implements Exception {
  const BackOfficeApiException(this.message);

  final String message;

  @override
  String toString() => 'BackOfficeApiException: $message';
}
