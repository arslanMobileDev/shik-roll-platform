import 'package:flutter/foundation.dart';

/// Runtime configuration for the KDS app, supplied via `--dart-define`.
///
/// Demo repositories require the explicit `ALLOW_MOCKS=true` build flag.
abstract final class KdsConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const bool allowMocks = bool.fromEnvironment(
    'ALLOW_MOCKS',
    defaultValue: false,
  );

  static bool get useRemoteApi => !allowMocks;

  static const String defaultBrandId = String.fromEnvironment(
    'BRAND_ID',
    defaultValue: 'brand-shik-roll',
  );

  /// Fallback snapshot-polling interval while the kitchen SSE stream is down
  /// (ADR-1618 recovery contract).
  static const Duration fallbackPollInterval = Duration(seconds: 15);

  static void validate() {
    if (allowMocks) return;
    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      throw StateError('API_BASE_URL is required when ALLOW_MOCKS is false');
    }
    if (kReleaseMode && apiUri.scheme != 'https') {
      throw StateError('Release API_BASE_URL must use HTTPS');
    }
  }
}
