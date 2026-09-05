import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/storage/courier_auth_storage.dart';
import 'core/theme/shik_theme.dart';
import 'data/repositories/courier_repository.dart';
import 'features/auth/bloc/auth_cubit.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/view/courier_login_screen.dart';
import 'features/orders/view/courier_orders_screen.dart';

/// Root widget of the SHIK ROLL Courier App (Internal Use Only).
class CourierApp extends StatelessWidget {
  const CourierApp({
    super.key,
    required this.repository,
    required this.storage,
  });

  final CourierRepository repository;
  final CourierAuthStorage storage;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<CourierRepository>.value(
      value: repository,
      child: BlocProvider(
        create: (_) =>
            AuthCubit(repository: repository, storage: storage)..restore(),
        child: MaterialApp(
          title: 'SHIK ROLL Курьер',
          debugShowCheckedModeBanner: false,
          theme: ShikTheme.light(),
          darkTheme: ShikTheme.dark(),
          themeMode: ThemeMode.system,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthLoading() => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          AuthAuthenticated(session: final session) =>
            CourierOrdersScreen(session: session),
          _ => const CourierLoginScreen(),
        };
      },
    );
  }
}
