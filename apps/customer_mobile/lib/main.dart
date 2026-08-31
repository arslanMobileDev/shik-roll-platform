import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/menu/data/fake_customer_menu_repository.dart';
import 'features/menu/data/menu_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobile portrait orientation.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final CustomerMenuRepository repository = AppConfig.useRemoteMenu
      ? RemoteCustomerMenuRepository(
          ApiClient(baseUrl: AppConfig.apiBaseUrl),
        )
      : FakeCustomerMenuRepository(
          latency: const Duration(milliseconds: 200),
        );

  runApp(CustomerApp(repository: repository));
}
