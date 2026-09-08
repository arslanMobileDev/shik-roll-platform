import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/courier_auth_interceptor.dart';
import 'core/storage/courier_auth_storage.dart';
import 'core/storage/courier_token_storage.dart';
import 'core/theme/shik_theme.dart';
import 'data/repositories/courier_repository.dart';
import 'features/auth/bloc/auth_cubit.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/view/courier_login_screen.dart';
import 'features/location/data/courier_location_repository.dart';
import 'features/location/data/courier_location_source.dart';
import 'features/orders/view/courier_orders_screen.dart';

/// Root widget of the SHIK ROLL Courier App (Internal Use Only).
///
/// Composition root: the authenticated cubit owns restore/login/logout; the
/// optional [authInterceptor] (remote mode) forwards a 401 to
/// `sessionExpired` — the root gate then lands on the login screen.
class CourierApp extends StatelessWidget {
  const CourierApp({
    super.key,
    required this.repository,
    required this.locationRepository,
    required this.storage,
    required this.tokenStorage,
    this.authInterceptor,
    this.locationSource,
  });

  final CourierRepository repository;
  final CourierLocationRepository locationRepository;
  final CourierAuthStorage storage;
  final CourierTokenStorage tokenStorage;
  final CourierAuthInterceptor? authInterceptor;

  /// Test seam: overrides the geolocator-backed location source.
  final CourierLocationSource? locationSource;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CourierRepository>.value(value: repository),
        RepositoryProvider<CourierLocationRepository>.value(
          value: locationRepository,
        ),
      ],
      child: BlocProvider(
        create: (_) {
          final cubit = AuthCubit(
            repository: repository,
            storage: storage,
            tokenStorage: tokenStorage,
          );
          authInterceptor?.onUnauthorized = cubit.sessionExpired;
          return cubit..restore();
        },
        child: MaterialApp(
          title: 'SHIK ROLL Курьер',
          debugShowCheckedModeBanner: false,
          theme: ShikTheme.light(),
          darkTheme: ShikTheme.dark(),
          themeMode: ThemeMode.system,
          home: _AuthGate(locationSource: locationSource),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({this.locationSource});

  final CourierLocationSource? locationSource;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthLoading() => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          AuthAuthenticated(session: final session) => CourierOrdersScreen(
            session: session,
            locationSource: locationSource,
          ),
          _ => const CourierLoginScreen(),
        };
      },
    );
  }
}
