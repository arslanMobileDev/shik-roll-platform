import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/auth/auth_token_provider.dart';
import 'core/auth/auth_token_storage.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/cart/data/orders_repository.dart';
import 'features/loyalty/data/loyalty_repository.dart';
import 'features/menu/data/menu_repository.dart';
import 'features/orders/data/order_history_repository.dart';
import 'features/orders/data/order_tracking_repository.dart';
import 'features/payments/data/payments_repository.dart';
import 'features/profile/data/user_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  // Mobile portrait orientation.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Live guest session token, shared by the authorized repositories.
  final tokenProvider = AuthTokenProvider();

  final CustomerMenuRepository repository = RemoteCustomerMenuRepository(
    ApiClient(baseUrl: AppConfig.apiBaseUrl),
  );

  final CustomerOrdersRepository ordersRepository =
      RemoteCustomerOrdersRepository(
        ApiClient(baseUrl: AppConfig.apiBaseUrl),
        tokenProvider,
      );

  final CustomerPaymentsRepository paymentsRepository =
      RemoteCustomerPaymentsRepository(
        ApiClient(baseUrl: AppConfig.apiBaseUrl),
        tokenProvider,
      );

  final AuthRepository authRepository = RemoteAuthRepository(
    ApiClient(baseUrl: AppConfig.apiBaseUrl),
    tokenProvider,
  );

  final OrderHistoryRepository orderHistoryRepository =
      RemoteOrderHistoryRepository(
        ApiClient(baseUrl: AppConfig.apiBaseUrl),
        tokenProvider,
      );

  // Realtime-трекинг статуса заказа (ADR-1615): SSE + fallback-поллинг.
  final OrderTrackingRepository orderTrackingRepository =
      RemoteOrderTrackingRepository(
        ApiClient(baseUrl: AppConfig.apiBaseUrl),
        tokenProvider,
      );

  // Программа лояльности (ADR-1614): баланс бонусов и лента акций.
  final LoyaltyRepository loyaltyRepository = RemoteLoyaltyRepository(
    ApiClient(baseUrl: AppConfig.apiBaseUrl),
    tokenProvider,
  );

  // Локальные UI-настройки гостя (ADR-1616).
  final userSettingsRepository = SharedPreferencesUserSettingsRepository(
    await SharedPreferences.getInstance(),
  );

  runApp(
    CustomerApp(
      repository: repository,
      ordersRepository: ordersRepository,
      paymentsRepository: paymentsRepository,
      authRepository: authRepository,
      tokenStorage: const SecureAuthTokenStorage(),
      tokenProvider: tokenProvider,
      orderHistoryRepository: orderHistoryRepository,
      orderTrackingRepository: orderTrackingRepository,
      userSettingsRepository: userSettingsRepository,
      loyaltyRepository: loyaltyRepository,
    ),
  );
}
