import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/auth_storage.dart';
import '../core/auth/session_events.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/login_cubit.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/view/login_screen.dart';

/// Decides what to render: the login form (no valid session) or the
/// authenticated shell. Reacts to 401 events from the API client, so an
/// expired token automatically returns the user to the login screen.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.authenticatedBuilder,
  });

  final AuthRepository authRepository;
  final WidgetBuilder authenticatedBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// null — checking storage; true/false — resolved.
  bool? _hasSession;
  StreamSubscription<void>? _unauthorizedSub;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _unauthorizedSub =
        SessionEvents.onUnauthorized.listen((_) => _onSessionLost());
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    final token = await AuthStorage.getToken();
    if (!mounted) return;
    setState(() => _hasSession = token != null && token.isNotEmpty);
  }

  void _onSessionLost() {
    if (mounted) setState(() => _hasSession = false);
  }

  void _onLoggedIn() {
    if (mounted) setState(() => _hasSession = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSession == null) {
      return const Scaffold(
        backgroundColor: AppColors.scaffold,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.terracotta),
        ),
      );
    }
    if (_hasSession! == false) {
      return BlocProvider(
        create: (_) => LoginCubit(repository: widget.authRepository),
        child: LoginScreen(onLoggedIn: _onLoggedIn),
      );
    }
    return widget.authenticatedBuilder(context);
  }
}
