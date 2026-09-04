import 'package:flutter/material.dart';

import '../core/auth/auth_token_provider.dart';
import '../core/auth/auth_token_storage.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/cart/data/orders_repository.dart';
import '../features/menu/data/menu_repository.dart';
import '../features/orders/data/order_history_repository.dart';
import '../features/payments/data/payments_repository.dart';
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
  });

  final CustomerMenuRepository repository;
  final CustomerOrdersRepository ordersRepository;
  final CustomerPaymentsRepository paymentsRepository;
  final AuthRepository authRepository;
  final AuthTokenStorage tokenStorage;
  final AuthTokenProvider tokenProvider;
  final OrderHistoryRepository orderHistoryRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      ),
    );
  }
}
