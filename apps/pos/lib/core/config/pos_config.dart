/// Runtime configuration for the POS app, supplied via `--dart-define`.
///
/// When [apiBaseUrl] is empty the app runs against an in-memory demo
/// catalog, which keeps the cashier screen usable for development and
/// widget tests without a backend.
abstract final class PosConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String defaultBrandId = String.fromEnvironment(
    'BRAND_ID',
    defaultValue: 'brand-shik-roll',
  );

  static const String defaultBranchId = String.fromEnvironment(
    'BRANCH_ID',
    defaultValue: 'branch-central',
  );
}

/// Selectable brand option for [BrandSelector].
final class BrandOption {
  const BrandOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Selectable branch option for [BranchSelector].
final class BranchOption {
  const BranchOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// POS table option for the dine-in mode.
final class TableOption {
  const TableOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Static POS context options.
///
/// The Menu & Product API contract (openapi.json) exposes no brand, branch
/// or table listing endpoints yet, so the selectors are fed from
/// configuration until those endpoints land.
abstract final class PosDirectory {
  static const List<BrandOption> brands = [
    BrandOption(id: PosConfig.defaultBrandId, name: 'SHIK ROLL'),
  ];

  static const List<BranchOption> branches = [
    BranchOption(id: PosConfig.defaultBranchId, name: 'Центральный'),
    BranchOption(id: 'branch-north', name: 'Северный'),
  ];

  static final List<TableOption> tables = [
    for (var i = 1; i <= 12; i++) TableOption(id: 'table-$i', label: 'Стол $i'),
  ];
}
