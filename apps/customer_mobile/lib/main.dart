import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/cart/data/fake_orders_repository.dart';
import 'features/cart/data/orders_repository.dart';
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

  final CustomerOrdersRepository ordersRepository = AppConfig.useRemoteMenu
      ? RemoteCustomerOrdersRepository(
          ApiClient(baseUrl: AppConfig.apiBaseUrl),
        )
      : FakeCustomerOrdersRepository(
          latency: const Duration(milliseconds: 600),
        );

  runApp(CustomerApp(repository: repository, ordersRepository: ordersRepository));
}
