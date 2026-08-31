/// Runtime configuration for the guest app.
abstract final class AppConfig {
  /// Base URL of the Menu & Product API (API-706). Passed via
  /// `--dart-define=API_BASE_URL=https://…`; when absent the app falls back
  /// to the in-memory demo menu ([FakeCustomerMenuRepository]).
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get useRemoteMenu => apiBaseUrl.isNotEmpty;
}
