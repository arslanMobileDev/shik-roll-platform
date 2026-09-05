import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/courier_auth_storage.dart';
import 'data/repositories/fake_courier_repository.dart';
import 'data/repositories/remote_courier_repository.dart';

/// API base URL; when empty the app runs on [FakeCourierRepository].
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Compact courier UI is portrait-only.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final storage = CourierAuthStorage(prefs);

  final repository = _apiBaseUrl.isEmpty
      ? FakeCourierRepository()
      : RemoteCourierRepository(baseUrl: _apiBaseUrl);

  runApp(CourierApp(repository: repository, storage: storage));
}
