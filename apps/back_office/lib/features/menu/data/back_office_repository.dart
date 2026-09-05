import 'models/menu_item.dart';

/// Menu catalog data source (API-706 v1.2.0 contract).
abstract interface class BackOfficeRepository {
  /// GET /menu-items?branchId={id}
  Future<List<MenuItem>> fetchMenuItems({required String branchId});

  /// POST /menu-items
  Future<MenuItem> createMenuItem(MenuItemDraft draft);

  /// PATCH /menu-items/{id}
  Future<MenuItem> updateMenuItem(MenuItem item);

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
