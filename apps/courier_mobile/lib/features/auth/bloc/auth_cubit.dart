import 'package:bloc/bloc.dart';

import '../../../core/constants/shik_branches.dart';
import '../../../core/network/courier_jwt.dart';
import '../../../core/storage/courier_auth_storage.dart';
import '../../../core/storage/courier_token_storage.dart';
import '../../../data/models/branch.dart';
import '../../../data/models/courier_session.dart';
import '../../../data/repositories/courier_repository.dart';
import 'auth_state.dart';

/// Courier authentication (ADR-1617): PIN login, async session restore with
/// one-time legacy migration, logout and 401-driven session expiry.
///
/// The JWT lives only in secure storage; the SharedPreferences profile holds
/// just courier/branch/phone. PIN, token and coordinates are never logged.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this._repository,
    required this._storage,
    required this._tokenStorage,
  }) : super(const AuthLoading());

  final CourierRepository _repository;
  final CourierAuthStorage _storage;
  final CourierTokenStorage _tokenStorage;

  /// Restores the persisted session (called once at app start).
  ///
  /// Order: read secure token -> if absent, try the one-time legacy v1
  /// migration -> validate expiry -> re-attach the stored profile. A missing,
  /// malformed or expired token clears both storages and lands on login.
  Future<void> restore() async {
    try {
      var token = await _tokenStorage.read();

      if (token == null) {
        final legacy = await _storage.extractLegacySession();
        if (legacy != null) {
          token = legacy.token;
          await _tokenStorage.write(token);
          await _storage.saveProfile(legacy);
        }
      }

      if (token == null || _isExpired(token)) {
        await _clearSession();
        emit(const AuthUnauthenticated());
        return;
      }

      final session = _storage.loadProfile(token: token);
      if (session == null) {
        await _clearSession();
        emit(const AuthUnauthenticated());
        return;
      }
      emit(AuthAuthenticated(session));
    } catch (_) {
      await _clearSession();
      emit(const AuthUnauthenticated());
    }
  }

  /// POST /couriers/auth/pin — identity and branch come from the server;
  /// the client never sends a branchId (ADR-1617).
  Future<void> login({required String pin, required String phone}) async {
    emit(const AuthLoading());
    try {
      final normalizedPhone = normalizePhone(phone);
      final result = await _repository.loginWithPin(
        pin: pin,
        phone: normalizedPhone,
      );
      final session = CourierSession(
        token: result.token,
        courier: result.courier,
        branch: _branchFromToken(result.token),
        phone: normalizedPhone,
      );
      await _tokenStorage.write(result.token);
      await _storage.saveProfile(session);
      emit(AuthAuthenticated(session));
    } on CourierAuthException catch (e) {
      emit(AuthFailure(e.message));
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthFailure('Ошибка входа. Попробуйте ещё раз'));
      emit(const AuthUnauthenticated());
    }
  }

  /// Manual logout: clears storages, then the auth gate shows login.
  /// SSE/location subscriptions live below the gate and are disposed with it.
  Future<void> logout() async {
    await _clearSession();
    emit(const AuthUnauthenticated());
  }

  /// 401 from any guarded request (single-flight via CourierAuthInterceptor):
  /// the token is dead — drop the session and return to the login screen.
  Future<void> sessionExpired() async {
    await _clearSession();
    emit(const AuthUnauthenticated());
  }

  bool _isExpired(String token) {
    final payload = CourierJwtPayload.tryParse(token);
    // A malformed token or one without exp cannot be trusted.
    return payload == null || payload.isExpired;
  }

  Branch _branchFromToken(String token) {
    final branchId = CourierJwtPayload.tryParse(token)?.branchId;
    if (branchId == null) return shikBranches.first;
    return shikBranches.firstWhere(
      (b) => b.id == branchId,
      orElse: () => Branch(id: branchId, name: branchId),
    );
  }

  Future<void> _clearSession() async {
    await _tokenStorage.clear();
    await _storage.clear();
  }
}

/// Normalizes a phone to E.164 (+7...) from common RU input formats.
String normalizePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  if (digits.length == 10) digits = '7$digits';
  return '+$digits';
}
