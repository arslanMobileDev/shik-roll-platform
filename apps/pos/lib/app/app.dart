import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/config/pos_config.dart';
import '../core/config/pos_context_cubit.dart';
import '../core/theme/app_theme.dart';
import '../features/cart/bloc/cart_bloc.dart';
import '../features/cashier/view/cashier_screen.dart';
import '../features/catalog/bloc/catalog_bloc.dart';
import '../features/catalog/bloc/catalog_event.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/tables/bloc/order_mode_cubit.dart';
import 'injection.dart';

/// SHIK Platform POS application (UI-806).
class PosApp extends StatelessWidget {
  PosApp({super.key, CatalogRepository? catalogRepository})
    : _catalogRepository =
          catalogRepository ?? getIt<CatalogRepository>(),
      _router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const CashierScreen(),
          ),
        ],
      );

  final CatalogRepository _catalogRepository;
  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PosContextCubit()),
        BlocProvider(
          create: (_) => CatalogBloc(repository: _catalogRepository)
            ..add(
              const CatalogStarted(
                brandId: PosConfig.defaultBrandId,
                branchId: PosConfig.defaultBranchId,
              ),
            ),
        ),
        BlocProvider(create: (_) => CartBloc()),
        BlocProvider(create: (_) => OrderModeCubit()),
      ],
      child: MaterialApp.router(
        title: 'SHIK POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
