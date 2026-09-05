// ignore_for_file: prefer_initializing_formals
// Named public parameters initialize private fields by design.
import 'package:bloc/bloc.dart';

import '../../../core/storage/courier_auth_storage.dart';
import '../../../data/models/branch.dart';
import '../../../data/models/courier_session.dart';
import '../../../data/repositories/courier_repository.dart';
import 'auth_state.dart';

/// Courier authentication: PIN login, session restore, logout.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required CourierRepository repository,
    required CourierAuthStorage storage,
  })  : _repository = repository,
        _storage = storage,
        super(const AuthLoading());

  final CourierRepository _repository;
  final CourierAuthStorage _storage;

  /// Restores a persisted session (called once at app start).
  Future<void> restore() async {
    final session = _storage.load();
    if (session != null) {
      emit(AuthAuthenticated(session));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> login({
    required String pin,
    required String phone,
    required Branch branch,
  }) async {
    emit(const AuthLoading());
    try {
      final result = await _repository.loginWithPin(pin: pin, phone: phone);
      final session = CourierSession(
        token: result.token,
        courier: result.courier,
        branch: branch,
        phone: phone,
      );
      await _storage.save(session);
      emit(AuthAuthenticated(session));
    } on CourierAuthException catch (e) {
      emit(AuthFailure(e.message));
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthFailure('Ошибка входа. Попробуйте ещё раз'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    emit(const AuthUnauthenticated());
  }
}
