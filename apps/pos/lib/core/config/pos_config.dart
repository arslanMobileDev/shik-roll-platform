/// Runtime configuration for the POS app, supplied via `--dart-define`.
abstract final class PosConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String defaultBrandId = String.fromEnvironment(
    'BRAND_ID',
    defaultValue: '37b84f4c-0a70-4263-bfa0-cc04ba0d4b99',
  );

  static const String defaultBranchId = String.fromEnvironment(
    'BRANCH_ID',
    defaultValue: '47ad77ce-acf4-4778-a185-974d3a4a2413',
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
abstract final class PosDirectory {
  static const List<BrandOption> brands = [
    BrandOption(id: PosConfig.defaultBrandId, name: 'SHIK ROLL'),
  ];

  static const List<BranchOption> branches = [
    BranchOption(id: PosConfig.defaultBranchId, name: 'Центральный'),
  ];

  static final List<TableOption> tables = [
    for (var i = 1; i <= 12; i++) TableOption(id: 'table-$i', label: 'Стол $i'),
  ];
}
