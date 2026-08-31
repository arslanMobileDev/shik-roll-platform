/// Runtime configuration for the guest app.
abstract final class AppConfig {
  /// Base URL of the Menu & Product API (API-706). Passed via
  /// `--dart-define=API_BASE_URL=https://…`; when absent the app falls back
  /// to the in-memory demo menu ([FakeCustomerMenuRepository]).
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get useRemoteMenu => apiBaseUrl.isNotEmpty;

  /// Branch the guest order is routed to. Passed via
  /// `--dart-define=BRANCH_ID=…`; the demo value matches the seeded dev data.
  static const String defaultBranchId = String.fromEnvironment(
    'BRANCH_ID',
    defaultValue: 'branch-demo',
  );
}
