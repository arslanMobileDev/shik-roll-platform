/// Runtime configuration for the KDS app, supplied via `--dart-define`.
///
/// When [apiBaseUrl] is empty the app runs against an in-memory demo order
/// stream, which keeps the kitchen board usable for development and widget
/// tests without a backend.
abstract final class KdsConfig {
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

  /// Auto-refresh interval for the kitchen board (API polling).
  static const Duration pollInterval = Duration(seconds: 10);
}
