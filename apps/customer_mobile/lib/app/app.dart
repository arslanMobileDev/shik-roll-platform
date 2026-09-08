import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/auth_token_provider.dart';
import '../core/auth/auth_token_storage.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/cart/data/orders_repository.dart';
import '../features/menu/data/menu_repository.dart';
import '../features/orders/data/order_history_repository.dart';
import '../features/orders/data/order_tracking_repository.dart';
import '../features/payments/data/payments_repository.dart';
import '../features/profile/bloc/user_settings_cubit.dart';
import '../features/profile/data/user_settings_repository.dart';
import '../features/shell/home_shell.dart';

/// Root widget; theme and startup route for the guest app.
class CustomerApp extends StatelessWidget {
  const CustomerApp({
    super.key,
    required this.repository,
    required this.ordersRepository,
    required this.paymentsRepository,
    required this.authRepository,
    required this.tokenStorage,
    required this.tokenProvider,
    required this.orderHistoryRepository,
    required this.orderTrackingRepository,
    required this.userSettingsRepository,
  });

  final CustomerMenuRepository repository;
  final CustomerOrdersRepository ordersRepository;
  final CustomerPaymentsRepository paymentsRepository;
  final AuthRepository authRepository;
  final AuthTokenStorage tokenStorage;
  final AuthTokenProvider tokenProvider;
  final OrderHistoryRepository orderHistoryRepository;
  final OrderTrackingRepository orderTrackingRepository;
  final UserSettingsRepository userSettingsRepository;

  @override
  Widget build(BuildContext context) {
    // Настройки гостя живут над корневым navigator и загружаются при старте,
    // чтобы любой экран (включая pushed-роуты) видел один источник (ADR-1616).
    return BlocProvider<UserSettingsCubit>(
      lazy: false,
      create: (_) => UserSettingsCubit(userSettingsRepository)..load(),
      child: MaterialApp(
        title: 'SHIK ROLL',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: HomeShell(
          repository: repository,
          ordersRepository: ordersRepository,
          paymentsRepository: paymentsRepository,
          authRepository: authRepository,
          tokenStorage: tokenStorage,
          tokenProvider: tokenProvider,
          orderHistoryRepository: orderHistoryRepository,
          orderTrackingRepository: orderTrackingRepository,
        ),
      ),
    );
  }
}
