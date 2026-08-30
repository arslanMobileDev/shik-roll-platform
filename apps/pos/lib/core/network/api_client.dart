import 'package:dio/dio.dart';

/// HTTP client for the SHIK Platform Menu & Product API (API-706).
///
/// Thin wrapper over Dio: base URL, timeouts and JSON defaults live here so
/// repositories stay transport-agnostic.
final class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          );

  final Dio dio;
}
