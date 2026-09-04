import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_token_provider.dart';
import '../../../core/auth/auth_token_storage.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Guest SMS/OTP session: sends the code, verifies it, persists the JWT
/// pair in [AuthTokenStorage] and exposes the live access token through
/// [AuthTokenProvider] for the authorized repositories.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._repository,
    required this._tokenStorage,
    required this._tokenProvider,
  }) : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthOtpSendRequested>(_onOtpSendRequested);
    on<AuthOtpResendRequested>(_onOtpResendRequested);
    on<AuthOtpVerifyRequested>(_onOtpVerifyRequested);
    on<AuthOtpCancelled>(_onOtpCancelled);
    on<AuthNameSubmitted>(_onNameSubmitted);
    on<AuthLoggedOut>(_onLoggedOut);
  }

  final AuthRepository _repository;
  final AuthTokenStorage _tokenStorage;
  final AuthTokenProvider _tokenProvider;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final stored = await _tokenStorage.read();
    if (stored == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    _tokenProvider.accessToken = stored.accessToken;
    emit(
      AuthState(
        status: AuthStatus.authenticated,
        phone: stored.phone,
        customer: GuestCustomer(
          id: stored.customerId,
          phone: stored.phone,
          name: stored.name,
        ),
      ),
    );
    // Refresh the profile; drop the session only when the token is rejected.
    try {
      final profile = await _repository.getProfile();
      final name = profile.name ?? stored.name;
      emit(state.copyWith(customer: profile.copyWith(name: name)));
    } on AuthException catch (e) {
      if (e.isUnauthorized) {
        await _dropSession();
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
      // Network failure: keep the restored session (offline tolerant).
    }
  }

  Future<void> _onOtpSendRequested(
    AuthOtpSendRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        phone: event.phone,
        isLoading: true,
        clearError: true,
      ),
    );
    await _sendCode(emit, event.phone);
  }

  Future<void> _onOtpResendRequested(
    AuthOtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    final phone = state.phone;
    if (phone == null || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    await _sendCode(emit, phone);
  }

  Future<void> _sendCode(Emitter<AuthState> emit, String phone) async {
    try {
      final challenge = await _repository.sendOtp(phone: phone);
      emit(
        AuthState(
          status: AuthStatus.otpSent,
          phone: challenge.phone,
          otpExpiresInSeconds: challenge.expiresInSeconds,
        ),
      );
    } on AuthException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: e.message,
        ),
      );
    }
  }

  Future<void> _onOtpVerifyRequested(
    AuthOtpVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    final phone = state.phone;
    if (phone == null || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final session = await _repository.verifyOtp(
        phone: phone,
        code: event.code,
      );
      await _tokenStorage.save(session.toStored());
      _tokenProvider.accessToken = session.accessToken;
      emit(
        AuthState(
          status: AuthStatus.authenticated,
          phone: session.customer.phone,
          customer: session.customer,
        ),
      );
    } on AuthException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.otpSent,
          isLoading: false,
          errorMessage: e.message,
        ),
      );
    }
  }

  void _onOtpCancelled(AuthOtpCancelled event, Emitter<AuthState> emit) {
    emit(
      AuthState(status: AuthStatus.unauthenticated, phone: state.phone),
    );
  }

  Future<void> _onNameSubmitted(
    AuthNameSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final customer = state.customer;
    final name = event.name.trim();
    if (customer == null || name.isEmpty) return;
    emit(state.copyWith(customer: customer.copyWith(name: name)));
    final stored = await _tokenStorage.read();
    if (stored != null) {
      await _tokenStorage.save(stored.copyWith(name: name));
    }
  }

  Future<void> _onLoggedOut(
    AuthLoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    await _dropSession();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _dropSession() async {
    _tokenProvider.accessToken = null;
    await _tokenStorage.clear();
  }
}
