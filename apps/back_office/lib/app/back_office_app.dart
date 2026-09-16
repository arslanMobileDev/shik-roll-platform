import '../core/config/api_config.dart';
import '../features/dashboard/data/cooks_analytics_repository.dart';
import '../features/cooks/data/cooks_repository.dart';
import '../features/cooks/bloc/cooks_cubit.dart';
import '../features/cooks/view/cooks_screen.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/dashboard/bloc/dashboard_cubit.dart';
import '../features/dashboard/view/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/branch_settings/bloc/branch_settings_cubit.dart';
import '../features/branch_settings/view/branch_settings_screen.dart';
import '../features/cook_shifts/bloc/cook_shifts_cubit.dart';
import '../features/cook_shifts/data/cook_shifts_repository.dart';
import '../features/cook_shifts/view/cook_shifts_screen.dart';
import '../features/menu/bloc/menu_catalog_bloc.dart';
import '../features/menu/bloc/menu_catalog_event.dart';
import '../features/menu/data/back_office_repository.dart';
import '../features/menu/view/menu_list_screen.dart';
import '../features/menu/view/stop_list_screen.dart';
import '../features/orders/bloc/orders_journal_bloc.dart';
import '../features/orders/bloc/orders_journal_event.dart';
import '../features/orders/data/orders_repository.dart';
import '../features/orders/view/orders_journal_screen.dart';
import '../features/shell/bloc/branch_cubit.dart';
import '../features/shell/view/back_office_shell.dart';
import 'auth_gate.dart';

/// SHIK ROLL Back Office root widget (Flutter Web, ADR-1600 / UI-805).
///
/// Wraps the shell with [AuthGate]: unauthenticated visitors see the login
/// form, once a staff token is stored the shell renders. A 401 from any
/// request drops the session and returns the login screen automatically.
class BackOfficeApp extends StatelessWidget {
  const BackOfficeApp({
    super.key,
    required this.authRepository,
    required this.repository,
    required this.cookShiftsRepository,
    required this.ordersRepository,
    required this.dashboardRepository,
  });

  final AuthRepository authRepository;
  final BackOfficeRepository repository;
  final CookShiftsRepository cookShiftsRepository;
  final OrdersRepository ordersRepository;
  final DashboardRepository dashboardRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHIK ROLL · Back Office',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AuthGate(
        authRepository: authRepository,
        authenticatedBuilder: (_) => _AuthenticatedShell(
          repository: repository,
          cookShiftsRepository: cookShiftsRepository,
          ordersRepository: ordersRepository,
          dashboardRepository: dashboardRepository,
        ),
      ),
    );
  }
}

/// The authenticated tree: repository provider, blocs and the shell.
/// Only built after AuthGate confirms a valid session.
class _AuthenticatedShell extends StatelessWidget {
  const _AuthenticatedShell({
    required this.repository,
    required this.cookShiftsRepository,
    required this.ordersRepository,
    required this.dashboardRepository,
  });

  final BackOfficeRepository repository;
  final CookShiftsRepository cookShiftsRepository;
  final OrdersRepository ordersRepository;
  final DashboardRepository dashboardRepository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<BackOfficeRepository>.value(
      value: repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => BranchCubit()),
          BlocProvider(
            create: (context) =>
                CooksCubit(CooksRepository())
                  ..load(context.read<BranchCubit>().state.id),
          ),
          BlocProvider(
            create: (context) => DashboardCubit(
              repository: dashboardRepository,
              cooksRepository: ApiConfig.useFakeRepository
                  ? EmptyCooksAnalyticsRepository()
                  : RemoteCooksAnalyticsRepository(),
            )..load(context.read<BranchCubit>().state.id),
          ),
          BlocProvider(
            create: (_) => MenuCatalogBloc(repository: repository)
              ..add(
                MenuCatalogRequested(branchId: BranchCubit.branches.first.id),
              ),
          ),
          BlocProvider(
            create: (_) =>
                BranchSettingsCubit()
                  ..selectBranch(BranchCubit.branches.first.id),
          ),
          BlocProvider(
            create: (_) =>
                CookShiftsCubit(repository: cookShiftsRepository)
                  ..load(BranchCubit.branches.first.id),
          ),
          BlocProvider(
            create: (_) => OrdersJournalBloc(repository: ordersRepository)
              ..add(
                OrdersJournalRequested(branchId: BranchCubit.branches.first.id),
              ),
          ),
        ],
        child: BlocListener<BranchCubit, Branch>(
          listener: (context, branch) {
            context.read<DashboardCubit>().load(branch.id);
            context.read<CooksCubit>().load(branch.id);
            context.read<CookShiftsCubit>().load(branch.id);
          },
          child: BackOfficeShell(
            sectionBuilder: (section) => switch (section) {
              BackOfficeSection.dashboard => const DashboardScreen(),
              BackOfficeSection.menu => const MenuListScreen(),
              BackOfficeSection.stopLists => const StopListScreen(),
              BackOfficeSection.orders => const OrdersJournalScreen(),
              BackOfficeSection.cooks => const CooksScreen(),
              BackOfficeSection.cookShifts => const CookShiftsScreen(),
              BackOfficeSection.branchSettings => const BranchSettingsScreen(),
            },
          ),
        ),
      ),
    );
  }
}
