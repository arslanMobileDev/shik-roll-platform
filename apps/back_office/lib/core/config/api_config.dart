/// Runtime configuration resolved from `--dart-define` flags.
abstract final class ApiConfig {
  /// Backend REST base URL (menu catalog API-706 v1.2.0).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// When true the app runs on [FakeBackOfficeRepository] demo data
  /// instead of the remote backend (useful while the backend is offline).
  static const bool useFakeRepository = bool.fromEnvironment(
    'USE_FAKE_REPOSITORY',
    defaultValue: true,
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
