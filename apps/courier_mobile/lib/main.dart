import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/courier_auth_interceptor.dart';
import 'core/storage/courier_auth_storage.dart';
import 'core/storage/courier_token_storage.dart';
import 'data/repositories/courier_repository.dart';
import 'data/repositories/fake_courier_repository.dart';
import 'data/repositories/remote_courier_repository.dart';
import 'features/location/data/courier_location_repository.dart';

/// API base URL; when empty the app runs on [FakeCourierRepository].
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Compact courier UI is portrait-only.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final storage = CourierAuthStorage(prefs);
  // ADR-1617: the courier JWT lives only in platform secure storage.
  // flutter_secure_storage v11: AES-GCM + KeyStore wrapping (API 23+).
  const tokenStorage = SecureCourierTokenStorage(
    FlutterSecureStorage(aOptions: AndroidOptions()),
  );

  CourierAuthInterceptor? authInterceptor;
  final CourierRepository repository;
  final CourierLocationRepository locationRepository;
  if (_apiBaseUrl.isEmpty) {
    repository = FakeCourierRepository();
    locationRepository = FakeCourierLocationRepository();
  } else {
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    authInterceptor = CourierAuthInterceptor(tokenStorage: tokenStorage);
    dio.interceptors.add(authInterceptor);
    repository = RemoteCourierRepository(dio: dio);
    locationRepository = RemoteCourierLocationRepository(dio: dio);
  }

  runApp(
    CourierApp(
      repository: repository,
      locationRepository: locationRepository,
      storage: storage,
      tokenStorage: tokenStorage,
      authInterceptor: authInterceptor,
    ),
  );
}
