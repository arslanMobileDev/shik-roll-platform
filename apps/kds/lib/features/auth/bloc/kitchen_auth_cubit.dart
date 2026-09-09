import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/kitchen_session_store.dart';
import '../../../core/storage/kitchen_token_storage.dart';
import '../data/kitchen_auth_repository.dart';

sealed class KitchenAuthState extends Equatable {
  const KitchenAuthState();

  @override
  List<Object?> get props => [];
}

/// Restoring a persisted terminal session from storage.
final class KitchenAuthRestoring extends KitchenAuthState {
  const KitchenAuthRestoring();
}

/// No valid session — the login form is shown. [busy] marks a login request
/// in flight; [errorMessage] carries the last failure (uniform, never
/// revealing whether the terminal code exists).
final class KitchenUnauthenticated extends KitchenAuthState {
  const KitchenUnauthenticated({this.errorMessage, this.busy = false});

  final String? errorMessage;
  final bool busy;

  KitchenUnauthenticated copyWith({
    String? Function()? errorMessage,
    bool? busy,
  }) => KitchenUnauthenticated(
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [errorMessage, busy];
}

/// Terminal authenticated — the board is available.
final class KitchenAuthenticated extends KitchenAuthState {
  const KitchenAuthenticated(this.session);

  final KitchenSession session;

  @override
  List<Object?> get props => [session];
}

/// Kitchen-terminal auth lifecycle (ADR-1618): restore the persisted session
/// on launch, PIN login, explicit logout and server-driven session expiry
/// (401 from any kitchen endpoint).
class KitchenAuthCubit extends Cubit<KitchenAuthState> {
  KitchenAuthCubit({
    required this.repository,
    required this.storage,
    required this.sessionStore,
  }) : super(const KitchenAuthRestoring());

  final KitchenAuthRepository repository;
  final KitchenTokenStorage storage;
  final KitchenSessionStore sessionStore;

  /// Restores the persisted session; an expired JWT is discarded locally
  /// without a network round-trip.
  Future<void> restore() async {
    KitchenSession? stored;
    try {
      stored = await storage.read();
    } on Object {
      stored = null;
    }
    if (stored != null &&
        stored.token.isNotEmpty &&
        !stored.isExpiredAt(DateTime.now())) {
      sessionStore.session = stored;
      emit(KitchenAuthenticated(stored));
      return;
    }
    if (stored != null) await storage.clear();
    sessionStore.session = null;
    emit(const KitchenUnauthenticated());
  }

  /// Logs the terminal in by code + 4-digit PIN and persists the session.
  Future<void> login({
    required String terminalCode,
    required String pin,
  }) async {
    final current = state;
    if (current is! KitchenUnauthenticated || current.busy) return;
    emit(current.copyWith(busy: true, errorMessage: () => null));
    try {
      final session = await repository.login(
        terminalCode: terminalCode,
        pin: pin,
      );
      sessionStore.session = session;
      try {
        await storage.write(session);
      } on Object {
        // Storage failure must not block a working session.
      }
      emit(KitchenAuthenticated(session));
    } on KitchenAuthException catch (e) {
      emit(current.copyWith(busy: false, errorMessage: () => e.message));
    } on Object {
      emit(
        current.copyWith(
          busy: false,
          errorMessage: () => 'Не удалось войти. Попробуйте ещё раз.',
        ),
      );
    }
  }

  /// Explicit logout from the board header.
  Future<void> logout() async {
    await _dropSession();
    emit(const KitchenUnauthenticated());
  }

  /// The backend rejected the terminal token (deactivated terminal or
  /// revoked JWT) — drop the session and ask for the PIN again.
  Future<void> handleSessionExpired() async {
    if (state is! KitchenAuthenticated) return;
    await _dropSession();
    emit(
      const KitchenUnauthenticated(
        errorMessage: 'Сессия терминала истекла. Войдите снова.',
      ),
    );
  }

  Future<void> _dropSession() async {
    sessionStore.session = null;
    try {
      await storage.clear();
    } on Object {
      // Nothing to do — the in-memory session is already gone.
    }
  }
}
