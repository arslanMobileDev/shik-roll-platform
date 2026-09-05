import 'package:equatable/equatable.dart';

import '../../../data/models/courier_session.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial / restoring persisted session.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No session — show login screen.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Session active — show orders screen.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final CourierSession session;

  @override
  List<Object?> get props => [session];
}

/// Login attempt failed; message shown on the login screen.
final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
