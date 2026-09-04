import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/auth/auth_token_provider.dart';
import 'core/auth/auth_token_storage.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/fake_auth_repository.dart';
import 'features/cart/data/fake_orders_repository.dart';
import 'features/cart/data/orders_repository.dart';
import 'features/menu/data/fake_customer_menu_repository.dart';
import 'features/menu/data/menu_repository.dart';
import 'features/orders/data/order_history_repository.dart';
import 'features/payments/data/fake_payments_repository.dart';
import 'features/payments/data/payments_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobile portrait orientation.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Live guest session token, shared by the authorized repositories.
  final tokenProvider = AuthTokenProvider();

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
          tokenProvider,
        )
      : FakeCustomerOrdersRepository(
          latency: const Duration(milliseconds: 600),
        );

  final CustomerPaymentsRepository paymentsRepository = AppConfig.useRemoteMenu
      ? RemoteCustomerPaymentsRepository(
          ApiClient(baseUrl: AppConfig.apiBaseUrl),
          tokenProvider,
        )
      : FakeCustomerPaymentsRepository(
          latency: const Duration(milliseconds: 400),
        );

  final AuthRepository authRepository = AppConfig.useRemoteMenu
      ? RemoteAuthRepository(
          ApiClient(baseUrl: AppConfig.apiBaseUrl),
          tokenProvider,
        )
      : FakeAuthRepository();

  final OrderHistoryRepository orderHistoryRepository =
      AppConfig.useRemoteMenu
      ? RemoteOrderHistoryRepository(
          ApiClient(baseUrl: AppConfig.apiBaseUrl),
          tokenProvider,
        )
      : FakeOrderHistoryRepository();

  runApp(
    CustomerApp(
      repository: repository,
      ordersRepository: ordersRepository,
      paymentsRepository: paymentsRepository,
      authRepository: authRepository,
      tokenStorage: const SecureAuthTokenStorage(),
      tokenProvider: tokenProvider,
      orderHistoryRepository: orderHistoryRepository,
    ),
  );
}
