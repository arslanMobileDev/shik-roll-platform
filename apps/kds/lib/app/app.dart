import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/audio/kitchen_alert_service.dart';
import '../core/config/kds_config.dart';
import '../core/storage/kitchen_token_storage.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/state_views.dart';
import '../features/auth/bloc/kitchen_auth_cubit.dart';
import '../features/auth/view/kitchen_login_screen.dart';
import '../features/kds/bloc/kds_orders_bloc.dart';
import '../features/kds/bloc/kds_orders_event.dart';
import '../features/kds/data/kds_orders_repository.dart';
import '../features/kds/data/kitchen_events_client.dart';
import '../features/kds/view/kds_screen.dart';
import '../features/shift/bloc/cook_shift_cubit.dart';
import '../features/shift/data/cook_shift_repository.dart';
import 'injection.dart';

/// SHIK Platform KDS — kitchen display system (UI-804 / ADR-1618).
///
/// The app gates on terminal authentication: restoring a persisted session,
/// the PIN login screen, or the authenticated board. Logging out disposes the
/// board subtree (streams, timers, polling) before the login screen returns.
class KdsApp extends StatelessWidget {
  KdsApp({
    super.key,
    KitchenAuthCubit? authCubit,
    KdsOrdersRepository? ordersRepository,
    KitchenEventsClient? eventsClient,
    CookShiftRepository? cookShiftRepository,
    KitchenAlertService? alertService,
  }) : _authCubit = authCubit ?? getIt<KitchenAuthCubit>(),
       _ordersRepository = ordersRepository ?? getIt<KdsOrdersRepository>(),
       _eventsClient = eventsClient ?? getIt<KitchenEventsClient>(),
       _cookShiftRepository =
           cookShiftRepository ?? getIt<CookShiftRepository>(),
       _alertService = alertService ?? getIt<KitchenAlertService>() {
    if (authCubit == null) unawaited(_authCubit.restore());
  }

  final KitchenAuthCubit _authCubit;
  final KdsOrdersRepository _ordersRepository;
  final KitchenEventsClient _eventsClient;
  final CookShiftRepository _cookShiftRepository;
  final KitchenAlertService _alertService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      child: MaterialApp(
        title: 'SHIK KDS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: BlocBuilder<KitchenAuthCubit, KitchenAuthState>(
          builder: (context, authState) => switch (authState) {
            KitchenAuthRestoring() => const Scaffold(
              body: LoadingView(label: 'Восстанавливаем сессию…'),
            ),
            KitchenUnauthenticated() => const KitchenLoginScreen(),
            KitchenAuthenticated(:final session) => _AuthenticatedBoard(
              key: ValueKey(session.terminalId),
              session: session,
              ordersRepository: _ordersRepository,
              eventsClient: _eventsClient,
              cookShiftRepository: _cookShiftRepository,
              alertService: _alertService,
            ),
          },
        ),
      ),
    );
  }
}

/// The board subtree for an authenticated terminal. Rebuilt from scratch on
/// every login ([ValueKey] on terminal), so a new session never inherits
/// stale blocs.
class _AuthenticatedBoard extends StatelessWidget {
  const _AuthenticatedBoard({
    super.key,
    required this.session,
    required this.ordersRepository,
    required this.eventsClient,
    required this.cookShiftRepository,
    required this.alertService,
  });

  final KitchenSession session;
  final KdsOrdersRepository ordersRepository;
  final KitchenEventsClient eventsClient;
  final CookShiftRepository cookShiftRepository;
  final KitchenAlertService alertService;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => KdsOrdersBloc(
            repository: ordersRepository,
            eventsClient: eventsClient,
            pollInterval: KdsConfig.fallbackPollInterval,
          )..add(const KdsOrdersStarted()),
        ),
        BlocProvider(
          create: (_) =>
              CookShiftCubit(repository: cookShiftRepository)
                ..load(session.branchId),
        ),
      ],
      child: KdsScreen(alertService: alertService),
    );
  }
}
