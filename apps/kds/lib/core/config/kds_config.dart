/// Runtime configuration for the KDS app, supplied via `--dart-define`.
///
/// When [apiBaseUrl] is empty the app runs in demo mode: a local PIN
/// (`0000`), an in-memory demo order stream and a silent events client keep
/// the kitchen board usable for development and widget tests without a
/// backend.
abstract final class KdsConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String defaultBrandId = String.fromEnvironment(
    'BRAND_ID',
    defaultValue: 'brand-shik-roll',
  );

  /// Fallback snapshot-polling interval while the kitchen SSE stream is down
  /// (ADR-1618 recovery contract).
  static const Duration fallbackPollInterval = Duration(seconds: 15);
}
