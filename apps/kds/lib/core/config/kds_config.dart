/// Runtime configuration for the KDS app, supplied via `--dart-define`.
///
/// The local backend is used by default. Pass an empty `API_BASE_URL` only
/// when the in-memory demo repositories are explicitly required.
abstract final class KdsConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String defaultBrandId = String.fromEnvironment(
    'BRAND_ID',
    defaultValue: 'brand-shik-roll',
  );

  static const String defaultBranchId = String.fromEnvironment(
    'BRANCH_ID',
    defaultValue: '47ad77ce-acf4-4778-a185-974d3a4a2413',
  );

  /// Auto-refresh interval for the kitchen board (API polling).
  static const Duration pollInterval = Duration(seconds: 10);
}
