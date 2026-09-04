import 'package:equatable/equatable.dart';

/// Commands accepted by [AuthBloc].
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// App start: restore the persisted session, if any.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Requests an SMS code for [phone] (E.164).
final class AuthOtpSendRequested extends AuthEvent {
  const AuthOtpSendRequested({required this.phone});

  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// Resends the code to the phone of the active challenge.
final class AuthOtpResendRequested extends AuthEvent {
  const AuthOtpResendRequested();
}

/// Submits the 4-digit [code] for the active challenge.
final class AuthOtpVerifyRequested extends AuthEvent {
  const AuthOtpVerifyRequested({required this.code});

  final String code;

  @override
  List<Object?> get props => [code];
}

/// Back from the code step to the phone step (code entry cancelled).
final class AuthOtpCancelled extends AuthEvent {
  const AuthOtpCancelled();
}

/// Saves a locally edited display name.
///
/// The auth contract has no profile-update endpoint, so the name is kept
/// in the stored session until the backend exposes one.
final class AuthNameSubmitted extends AuthEvent {
  const AuthNameSubmitted({required this.name});

  final String name;

  @override
  List<Object?> get props => [name];
}

/// Logs out: clears the persisted session and the live access token.
final class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}
