import 'package:equatable/equatable.dart';

import '../data/auth_models.dart';

/// Guest session lifecycle: anonymous → OTP sent → authenticated, with a
/// detour through [restoreOffered] for a phone whose account was deleted.
enum AuthStatus { unknown, unauthenticated, otpSent, restoreOffered, authenticated }

/// Single auth state; [AuthStatus] carries the step while [isLoading] and
/// [errorMessage] cover the Loading/Error cases without losing the context
/// (phone, customer) the UI still needs to render.
final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.phone,
    this.otpExpiresInSeconds = 0,
    this.customer,
    this.restoreOffer,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthStatus status;

  /// Phone of the active OTP challenge (E.164).
  final String? phone;

  /// Code lifetime reported by `POST /auth/otp/send`.
  final int otpExpiresInSeconds;

  /// Set when [status] is [AuthStatus.authenticated].
  final GuestCustomer? customer;

  /// Set when [status] is [AuthStatus.restoreOffered]: the deleted account
  /// found behind the verified phone, waiting for the guest's decision.
  final RestoreOffer? restoreOffer;

  /// A request (`send` / `verify` / restore) is in flight.
  final bool isLoading;

  /// Last failure to surface; cleared on the next successful action.
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    int? otpExpiresInSeconds,
    GuestCustomer? customer,
    RestoreOffer? restoreOffer,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      otpExpiresInSeconds: otpExpiresInSeconds ?? this.otpExpiresInSeconds,
      customer: customer ?? this.customer,
      restoreOffer: restoreOffer ?? this.restoreOffer,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    phone,
    otpExpiresInSeconds,
    customer,
    restoreOffer,
    isLoading,
    errorMessage,
  ];
}
