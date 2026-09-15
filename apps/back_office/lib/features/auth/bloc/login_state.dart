import 'package:equatable/equatable.dart';

import '../../../core/auth/auth_storage.dart';

/// Login form state machine.
///
/// idle        — initial / after a failed attempt the user is typing again
/// submitting  — request in flight, button disabled, spinner visible
/// success     — token saved; the app shell should replace the login screen
/// failure     — human-readable error message to display under the form
abstract class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginIdle extends LoginState {
  const LoginIdle();
}

class LoginSubmitting extends LoginState {
  const LoginSubmitting();
}

class LoginSuccess extends LoginState {
  const LoginSuccess(this.profile);
  final StaffProfile profile;

  @override
  List<Object?> get props => [profile];
}

class LoginFailure extends LoginState {
  const LoginFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
