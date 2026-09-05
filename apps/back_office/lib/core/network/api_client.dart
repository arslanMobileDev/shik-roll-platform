import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Thin Dio wrapper preconfigured for the menu catalog API.
final class ApiClient {
  ApiClient({String? baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          headers: const {'Content-Type': 'application/json'},
        ),
      );

  final Dio dio;
}
