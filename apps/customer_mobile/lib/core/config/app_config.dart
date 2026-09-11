import 'package:flutter/foundation.dart';

/// Runtime configuration for the guest app.
abstract final class AppConfig {
  /// Base URL of the production API, supplied through `--dart-define`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Branch the guest order is routed to. Passed via
  /// `--dart-define=BRANCH_ID=…`; the demo value matches the seeded dev data.
  static const String defaultBranchId = String.fromEnvironment(
    'BRANCH_ID',
    defaultValue: '',
  );

  /// Brand whose promotion feed is loaded (ADR-1614, `GET /promotions/feed`).
  /// Passed via `--dart-define=BRAND_ID=…`; the demo value matches the seeded
  /// SHIK ROLL brand.
  static const String defaultBrandId = String.fromEnvironment(
    'BRAND_ID',
    defaultValue: '',
  );

  static void validate() {
    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      throw StateError('API_BASE_URL is required');
    }
    if (kReleaseMode && apiUri.scheme != 'https') {
      throw StateError('Release API_BASE_URL must use HTTPS');
    }
    if (defaultBranchId.isEmpty || defaultBrandId.isEmpty) {
      throw StateError('BRANCH_ID and BRAND_ID are required');
    }
  }
}
